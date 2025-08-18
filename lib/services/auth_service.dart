import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'welcome_email_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: '159821446914-0rl4dgg8rl1g36vg4gnss90mc3ghhksa.apps.googleusercontent.com',
  );

  /// Get current user ID
  static String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// Get current user
  static User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Check if user is logged in
  static bool get isLoggedIn => getCurrentUser() != null;

  // Check internet connectivity
  static Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Initialize Supabase (call this in main.dart)
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign up with email and password
  static Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      // Check internet connectivity first
      if (!await _hasInternetConnection()) {
        throw Exception(
            'No internet connection. Please check your network and try again.');
      }

      // Validate input
      if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
        throw Exception('All fields are required');
      }

      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      // Validate email format
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('Please enter a valid email address');
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'avatar_url': '',
        },
      );

      if (response.user == null) {
        throw Exception('Sign up failed: No user returned');
      }

      // Create user profile in the profiles table
      try {
        await _createUserProfile(response.user!, fullName);
      } catch (e) {
        // Profile creation failed - this is critical for the app to work
        // Don't throw here as user account was created successfully
        // The profile will be created when they try to access it
      }

      // Send welcome email to new user
      try {
        final hasEmailBeenSent =
            await WelcomeEmailService.hasWelcomeEmailBeenSent(
                response.user!.id);
        if (!hasEmailBeenSent) {
          await WelcomeEmailService.sendWelcomeEmail(
            userId: response.user!.id,
            userEmail: email,
            userName: fullName,
          );
          await WelcomeEmailService.markWelcomeEmailSent(response.user!.id);
        }
      } catch (e) {
        // Don't break signup flow if welcome email fails
      }

      return response;
    } on SocketException {
      throw Exception(
          'Network error: Please check your internet connection and try again.');
    } on HttpException {
      throw Exception('Server error: Please try again later.');
    } on FormatException {
      throw Exception('Invalid response format. Please try again.');
    } on AuthException catch (e) {
      // Handle Supabase auth exceptions
      String errorMessage = 'Sign up failed';
      switch (e.statusCode) {
        case '400':
          errorMessage = 'Invalid email or password format';
          break;
        case '422':
          errorMessage = 'Email already registered';
          break;
        case '429':
          errorMessage = 'Too many requests. Please try again later';
          break;
        default:
          errorMessage = e.message ?? 'Sign up failed';
      }
      throw Exception(errorMessage);
    } on PlatformException catch (e) {
      // Handle platform-specific exceptions including channel connection issues
      String errorMessage = 'Platform error occurred';
      if (e.message != null) {
        if (e.message!.contains('channel')) {
          errorMessage =
              'Connection error: Please restart the app and try again.';
        } else if (e.message!.contains('network')) {
          errorMessage =
              'Network error: Please check your internet connection.';
        } else {
          errorMessage = 'Platform error: ${e.message}';
        }
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Handle any other exceptions
      String errorMessage = e.toString();
      if (errorMessage.contains('channel')) {
        throw Exception(
            'Connection error: Please restart the app and try again.');
      } else if (errorMessage.contains('network') ||
          errorMessage.contains('connection')) {
        throw Exception(
            'Network error: Please check your internet connection and try again.');
      } else {
        throw Exception('Sign up failed: Please try again.');
      }
    }
  }

  // Sign in with email and password
  static Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      // Check internet connectivity first
      if (!await _hasInternetConnection()) {
        throw Exception(
            'No internet connection. Please check your network and try again.');
      }

      // Validate input
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in failed: No user returned');
      }

      return response;
    } on SocketException {
      throw Exception(
          'Network error: Please check your internet connection and try again.');
    } on HttpException {
      throw Exception('Server error: Please try again later.');
    } on FormatException {
      throw Exception('Invalid response format. Please try again.');
    } on AuthException catch (e) {
      // Handle Supabase auth exceptions
      String errorMessage = 'Sign in failed';
      switch (e.statusCode) {
        case '400':
          errorMessage = 'Invalid email or password';
          break;
        case '401':
          errorMessage = 'Invalid login credentials';
          break;
        case '422':
          errorMessage = 'Email not confirmed';
          break;
        case '429':
          errorMessage = 'Too many requests. Please try again later';
          break;
        default:
          errorMessage = e.message ?? 'Sign in failed';
      }
      throw Exception(errorMessage);
    } on PlatformException catch (e) {
      // Handle platform-specific exceptions including channel connection issues
      String errorMessage = 'Platform error occurred';
      if (e.message != null) {
        if (e.message!.contains('channel')) {
          errorMessage =
              'Connection error: Please restart the app and try again.';
        } else if (e.message!.contains('network')) {
          errorMessage =
              'Network error: Please check your internet connection.';
        } else {
          errorMessage = 'Platform error: ${e.message}';
        }
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Handle any other exceptions
      String errorMessage = e.toString();
      if (errorMessage.contains('channel')) {
        throw Exception(
            'Connection error: Please restart the app and try again.');
      } else if (errorMessage.contains('network') ||
          errorMessage.contains('connection')) {
        throw Exception(
            'Network error: Please check your internet connection and try again.');
      } else {
        throw Exception('Sign in failed: Please try again.');
      }
    }
  }

  // Sign in with Google
  static Future<AuthResponse> signInWithGoogle() async {
    try {
      // Start Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      // Get Google Auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('Failed to get Google ID token');
      }

      // Sign in to Supabase with Google ID token
      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      // Handle successful sign-in
      final User? user = response.user;
      if (user != null) {
        try {
          // Create or update user profile
          await _createUserProfile(
            user,
            googleUser.displayName ?? 'Unknown User',
          );

          // Send welcome email
          final hasEmailBeenSent = await WelcomeEmailService.hasWelcomeEmailBeenSent(user.id);
          if (!hasEmailBeenSent) {
            await WelcomeEmailService.sendGoogleWelcomeEmail(
              userId: user.id,
              userEmail: googleUser.email,
              userName: googleUser.displayName ?? 'Unknown User',
            );
            await WelcomeEmailService.markWelcomeEmailSent(user.id);
          }
        } catch (e) {
          print('Post sign-in setup error: $e');
          // Don't throw here as sign-in was successful
        }
      }

      return response;
    } catch (e) {
      print('Google sign-in error: $e');
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
    } on SocketException {
      throw Exception(
          'Network error: Please check your internet connection and try again.');
    } on AuthException catch (e) {
      // Handle Supabase auth exceptions
      throw Exception('Sign out failed: ${e.message ?? 'Unknown error'}');
    } on PlatformException catch (e) {
      // Handle platform-specific exceptions including channel connection issues
      String errorMessage = 'Platform error occurred';
      if (e.message != null) {
        if (e.message!.contains('channel')) {
          errorMessage =
              'Connection error: Please restart the app and try again.';
        } else if (e.message!.contains('network')) {
          errorMessage =
              'Network error: Please check your internet connection.';
        } else {
          errorMessage = 'Platform error: ${e.message}';
        }
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Handle any other exceptions
      String errorMessage = e.toString();
      if (errorMessage.contains('channel')) {
        throw Exception(
            'Connection error: Please restart the app and try again.');
      } else if (errorMessage.contains('network') ||
          errorMessage.contains('connection')) {
        throw Exception(
            'Network error: Please check your internet connection and try again.');
      } else {
        throw Exception('Sign out failed: Please try again.');
      }
    }
  }

  /// Sends a password reset email to the specified email address
  static Future<void> resetPassword(String email) async {
    try {
      print('🔄 Starting password reset for email: $email');
      final String redirectUrl = 'edubazaar://reset-password';
      print('📱 Using redirect URL: $redirectUrl');

      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
      print('✅ Reset password email sent successfully');
    } catch (e) {
      print('❌ Failed to send reset password email: $e');
      throw 'Failed to send reset password email: ${e.toString()}';
    }
  }

  /// Updates user's password after reset
  static Future<void> updatePassword(String newPassword) async {
    try {
      print('🔄 Starting password update');
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
      print('✅ Password updated successfully');
    } catch (e) {
      print('❌ Failed to update password: $e');
      throw 'Failed to update password: ${e.toString()}';
    }
  }

  // Update user profile
  static Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final user = getCurrentUser();
      if (user == null) throw Exception('No user logged in');

      // Update auth user metadata
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': fullName,
            'avatar_url': avatarUrl,
          },
        ),
      );

      // Update user_profiles table
      await _supabase.from('user_profiles').update({
        'name': fullName, // Changed from 'full_name' to 'name'
        'profile_pic_url':
            avatarUrl, // Changed from 'avatar_url' to 'profile_pic_url'
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      throw Exception('Profile update failed: ${e.toString()}');
    }
  }

  // Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = getCurrentUser();
      if (user == null) return null;

      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  // Create user profile in database
  static Future<void> _createUserProfile(User user, String fullName) async {
    try {
      // First check if profile already exists
      final existingProfile = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile != null) {
        return;
      }

      // Create new profile
      final profileData = {
        'id': user.id,
        'name': fullName.isNotEmpty
            ? fullName
            : (user.email?.split('@')[0] ?? 'User'),
        'email': user.email ?? '',
        'profile_pic_url': user.userMetadata?['avatar_url'] ?? '',
        'cover_photo_url': '',
        'university': '',
        'course': '',
        'semester': '',
        'bio': '',
        'phone_number': '',
        'interests': [],
        'is_verified': false,
        'is_active': true,
        'last_active': DateTime.now().toIso8601String(),
        'joined_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('user_profiles').insert(profileData);
    } catch (e) {
      // Throw error instead of just printing so we can handle it
      throw Exception('Profile creation failed: ${e.toString()}');
    }
  }

  // Ensure user profile exists (for existing users)
  static Future<void> ensureUserProfileExists() async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        return;
      }

      final existingProfile = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        final displayName = user.userMetadata?['full_name'] as String? ??
            user.email?.split('@')[0] ??
            'User';
        await _createUserProfile(user, displayName);
      }
    } catch (e) {
      // Error ensuring profile exists handled silently
    }
  }

  // Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  // Generate a random nonce for Apple Sign-In (for future use)
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  // Generate SHA256 hash
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Test Google Sign-In configuration (for debugging)
  static Future<void> testGoogleSignInConfig() async {
    try {
      // Test 1: Check if Google Sign-In is properly initialized
      // Test 2: Check current signed-in user
      final currentUser = _googleSignIn.currentUser;

      // Test 3: Test sign-out first (clean slate)
      await _googleSignIn.signOut();

      // Test 4: Check if we can initiate sign-in
      final GoogleSignInAccount? testUser = await _googleSignIn.signIn();

      if (testUser != null) {
        // Test 5: Get authentication details
        final auth = await testUser.authentication;

        // Test 6: Sign out after test
        await _googleSignIn.signOut();
      }
    } catch (e) {
      // Test failed
    }
  }
}
