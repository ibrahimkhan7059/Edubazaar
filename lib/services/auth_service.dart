import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Completely remove serverClientId - this often fixes token issues
    hostedDomain: '',
    signInOption: SignInOption.standard,
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
      print('Supabase initialization failed: $e');
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
        print(
            '❌ Critical: Profile creation failed during sign up: ${e.toString()}');
        // Don't throw here as user account was created successfully
        // The profile will be created when they try to access it
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
      print('🔍 Starting Google Sign-In process...');

      // Check internet connectivity first
      if (!await _hasInternetConnection()) {
        throw Exception(
            'No internet connection. Please check your network and try again.');
      }
      print('✅ Internet connection verified');

      // Start Google Sign-In flow
      print('🔑 Starting Google sign-in flow...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('❌ Google sign-in cancelled by user');
        throw Exception('Google sign-in was cancelled');
      }
      print('✅ Google user account obtained: ${googleUser.email}');

      // Get Google Auth details
      print('🔐 Getting Google authentication tokens...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print(
            '❌ Failed to get Google tokens - Access: ${googleAuth.accessToken != null}, ID: ${googleAuth.idToken != null}');
        throw Exception('Failed to get Google authentication tokens');
      }
      print('✅ Google authentication tokens obtained');

      // Sign in to Supabase with Google credentials
      print('🔗 Signing in to Supabase with Google credentials...');
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken!,
      );

      if (response.user == null) {
        print('❌ Supabase sign-in failed - no user returned');
        throw Exception('Google sign-in failed: No user returned');
      }
      print('✅ Successfully signed in to Supabase: ${response.user!.email}');

      // Create or update user profile
      try {
        await _createUserProfile(
          response.user!,
          googleUser.displayName ?? 'Unknown User',
        );
        print('✅ User profile created/updated');
      } catch (e) {
        // Profile creation failed - this is critical for the app to work
        print(
            '❌ Critical: Profile creation failed during Google sign in: ${e.toString()}');
        // Don't throw here as user account was created successfully
        // The profile will be created when they try to access it
      }

      return response;
    } on SocketException catch (e) {
      print('❌ Network error: $e');
      throw Exception(
          'Network error: Please check your internet connection and try again.');
    } on HttpException catch (e) {
      print('❌ HTTP error: $e');
      throw Exception('Server error: Please try again later.');
    } on FormatException catch (e) {
      print('❌ Format error: $e');
      throw Exception('Invalid response format. Please try again.');
    } on AuthException catch (e) {
      // Handle Supabase auth exceptions
      print('❌ Supabase Auth error: ${e.message} (Code: ${e.statusCode})');
      throw Exception('Google sign-in failed: ${e.message ?? 'Unknown error'}');
    } on PlatformException catch (e) {
      // Handle platform-specific exceptions including channel connection issues
      print('❌ Platform error: ${e.message} (Code: ${e.code})');
      String errorMessage = 'Platform error occurred';
      if (e.message != null) {
        if (e.message!.contains('channel')) {
          errorMessage =
              'Connection error: Please restart the app and try again.';
        } else if (e.message!.contains('network')) {
          errorMessage =
              'Network error: Please check your internet connection.';
        } else if (e.message!.contains('DEVELOPER_ERROR')) {
          errorMessage =
              'Google Sign-In not configured properly. Please contact support.';
        } else if (e.code == '10') {
          errorMessage =
              'Google Sign-In configuration error. Please check Firebase setup.';
        } else {
          errorMessage = 'Platform error: ${e.message}';
        }
      }
      throw Exception(errorMessage);
    } catch (e) {
      // Handle any other exceptions
      print('❌ Unexpected error: $e');
      String errorMessage = e.toString();
      if (errorMessage.contains('channel')) {
        throw Exception(
            'Connection error: Please restart the app and try again.');
      } else if (errorMessage.contains('network') ||
          errorMessage.contains('connection')) {
        throw Exception(
            'Network error: Please check your internet connection and try again.');
      } else {
        throw Exception(
            'Google sign-in failed: Please try again. Error: $errorMessage');
      }
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

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      if (email.isEmpty) {
        throw Exception('Email is required');
      }

      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('Please enter a valid email address');
      }

      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      // Handle Supabase auth exceptions
      throw Exception('Password reset failed: ${e.message ?? 'Unknown error'}');
    } on PlatformException catch (e) {
      // Handle platform-specific exceptions
      throw Exception('Platform error: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      // Handle any other exceptions
      throw Exception('Password reset failed: ${e.toString()}');
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
        print('Profile already exists for user: ${user.id}');
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
      print('✅ Profile created successfully for user: ${user.id}');
    } catch (e) {
      print('❌ Profile creation failed: ${e.toString()}');
      // Throw error instead of just printing so we can handle it
      throw Exception('Profile creation failed: ${e.toString()}');
    }
  }

  // Ensure user profile exists (for existing users)
  static Future<void> ensureUserProfileExists() async {
    try {
      print('🔍 Checking if user profile exists...');
      final user = getCurrentUser();
      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      print('✅ User found: ${user.id}');

      final existingProfile = await _supabase
          .from('user_profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        print('⚠️ Profile not found for existing user, creating...');
        final displayName = user.userMetadata?['full_name'] as String? ??
            user.email?.split('@')[0] ??
            'User';
        print('📝 Creating profile with name: $displayName');
        await _createUserProfile(user, displayName);
        print('✅ Profile created successfully');
      } else {
        print('✅ Profile already exists');
      }
    } catch (e) {
      print('❌ Error ensuring profile exists: ${e.toString()}');
      print('❌ Error type: ${e.runtimeType}');
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
      print('🔍 Testing Google Sign-In configuration...');

      // Test 1: Check if Google Sign-In is properly initialized
      print(
          '📱 Google Sign-In configured with client ID: ${_googleSignIn.clientId}');

      // Test 2: Check current signed-in user
      final currentUser = _googleSignIn.currentUser;
      print('👤 Current user: ${currentUser?.email ?? 'None'}');

      // Test 3: Test sign-out first (clean slate)
      await _googleSignIn.signOut();
      print('🚪 Signed out from Google');

      // Test 4: Check if we can initiate sign-in
      print('🔑 Starting sign-in test...');
      final GoogleSignInAccount? testUser = await _googleSignIn.signIn();

      if (testUser != null) {
        print('✅ Sign-in successful: ${testUser.email}');
        print('📧 Display name: ${testUser.displayName}');
        print('🆔 User ID: ${testUser.id}');

        // Test 5: Get authentication details
        final auth = await testUser.authentication;
        print('🔐 Access token available: ${auth.accessToken != null}');
        print('🎫 ID token available: ${auth.idToken != null}');

        // Test 6: Sign out after test
        await _googleSignIn.signOut();
        print('✅ Test completed successfully');
      } else {
        print('❌ Sign-in returned null');
      }
    } catch (e) {
      print('❌ Test failed: $e');
    }
  }
}
 