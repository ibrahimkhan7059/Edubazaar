import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class ProfileService {
  static final _supabase = Supabase.instance.client;

  // Get current user's profile
  static Future<UserProfile> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final response = await _supabase
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .single();

    return UserProfile.fromJson(response as Map<String, dynamic>);
  }

  // Update user profile
  static Future<UserProfile> updateProfile(UserProfile profile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final response = await _supabase
        .from('user_profiles')
        .update(profile.toJson())
        .eq('id', user.id)
        .select()
        .single();

    return UserProfile.fromJson(response as Map<String, dynamic>);
  }

  // Upload profile picture
  static Future<String> uploadProfilePicture(File imageFile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final fileExt = imageFile.path.split('.').last;
    final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
    final storagePath = 'profile_pictures/${user.id}/$fileName';

    await _supabase.storage.from('avatars').upload(storagePath, imageFile);

    return _supabase.storage.from('avatars').getPublicUrl(storagePath);
  }

  // Upload cover photo
  static Future<String> uploadCoverPhoto(File imageFile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final fileExt = imageFile.path.split('.').last;
    final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
    final storagePath = 'cover_photos/${user.id}/$fileName';

    await _supabase.storage.from('covers').upload(storagePath, imageFile);

    return _supabase.storage.from('covers').getPublicUrl(storagePath);
  }

  // Get user stats
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    final listingsCount = await _supabase
        .from('listings')
        .select('id')
        .eq('user_id', userId)
        .count();

    final salesCount = await _supabase
        .from('transactions')
        .select('id')
        .eq('seller_id', userId)
        .eq('status', 'completed')
        .count();

    final reviewsResponse = await _supabase
        .from('user_reviews')
        .select('rating')
        .eq('reviewed_id', userId);

    double averageRating = 0;
    if (reviewsResponse.isNotEmpty) {
      final ratings = reviewsResponse as List<dynamic>;
      final sum = ratings.fold<double>(
          0, (sum, item) => sum + (item['rating'] as num).toDouble());
      averageRating = sum / ratings.length;
    }

    return {
      'total_listings': listingsCount,
      'total_sales': salesCount,
      'rating': averageRating,
    };
  }

  // Create initial profile for new user
  static Future<UserProfile> createProfile({
    required String userId,
    required String name,
    required String email,
  }) async {
    final profile = UserProfile(
      uid: userId,
      name: name,
      email: email,
      joinedDate: DateTime.now(),
    );

    final response = await _supabase
        .from('user_profiles')
        .insert(profile.toJson())
        .select()
        .single();

    return UserProfile.fromJson(response as Map<String, dynamic>);
  }
}
