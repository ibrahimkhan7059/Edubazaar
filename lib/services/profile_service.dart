import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../models/user_profile.dart';
import '../models/user_review.dart';
import '../models/user_transaction.dart';
import 'auth_service.dart';
import 'dart:async'; // Added for Timer

class ProfileService {
  static final _supabase = Supabase.instance.client;

  // ============================================
  // USER PROFILE OPERATIONS
  // ============================================

  /// Get user profile with real-time stats
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      // First ensure the profile exists in the database
      await AuthService.ensureUserProfileExists();

      // Get basic profile data
      final basicResponse = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .single();

      // Calculate real-time statistics
      final stats = await _calculateUserStats(userId);

      // Combine profile data with real-time stats
      final profileData = Map<String, dynamic>.from(basicResponse);
      profileData.addAll(stats);

      return UserProfile.fromJson(profileData);
    } catch (e) {
      return null;
    }
  }

  /// Calculate real-time user statistics from database
  static Future<Map<String, dynamic>> _calculateUserStats(String userId) async {
    try {
      // Initialize stats
      Map<String, dynamic> stats = {
        'total_listings': 0,
        'active_listings': 0,
        'sold_listings': 0,
        'average_rating': 0.0,
        'total_reviews': 0,
        'total_sales': 0,
        'total_purchases': 0,
        'total_donations_given': 0,
        'total_donations_received': 0,
      };

      // Parallel execution for better performance
      final futures = await Future.wait<dynamic>([
        // 1. Listings statistics
        _supabase
            .from('listings')
            .select('status')
            .eq('user_id', userId)
            .neq('status', 'deleted'),

        // 2. Reviews statistics
        _supabase
            .from('user_reviews')
            .select('rating')
            .eq('reviewed_id', userId),

        // 3. Sales count (if transactions table exists)
        _getTransactionCount(userId, 'seller_id'),

        // 4. Purchases count (if transactions table exists)
        _getTransactionCount(userId, 'buyer_id'),
      ]);

      // Process listings statistics
      final listings = futures[0] as List;
      stats['total_listings'] = listings.length;
      stats['active_listings'] =
          listings.where((l) => l['status'] == 'active').length;
      stats['sold_listings'] =
          listings.where((l) => l['status'] == 'sold').length;

      // Process reviews statistics
      final reviews = futures[1] as List;
      stats['total_reviews'] = reviews.length;
      if (reviews.isNotEmpty) {
        final totalRating = reviews.fold<double>(
            0, (sum, review) => sum + (review['rating'] as num).toDouble());
        stats['average_rating'] = totalRating / reviews.length;
      }

      // Process transaction statistics
      stats['total_sales'] = futures[2] as int;
      stats['total_purchases'] = futures[3] as int;

      return stats;
    } catch (e) {
      // Return default stats on error
      return {
        'total_listings': 0,
        'active_listings': 0,
        'sold_listings': 0,
        'average_rating': 0.0,
        'total_reviews': 0,
        'total_sales': 0,
        'total_purchases': 0,
        'total_donations_given': 0,
        'total_donations_received': 0,
      };
    }
  }

  /// Helper method to get transaction count (with table existence check)
  static Future<int> _getTransactionCount(String userId, String column) async {
    try {
      final result = await _supabase
          .from('user_transactions')
          .select('id')
          .eq(column, userId);
      return result.length;
    } catch (e) {
      // Table might not exist yet
      return 0;
    }
  }

  /// Create initial profile for new user
  static Future<void> createInitialProfile(
      String userId, String name, String email) async {
    try {
      final profileData = {
        'id': userId,
        'name': name,
        'email': email,
        'joined_date': DateTime.now().toIso8601String(),
        'is_active': true,
      };

      await _supabase.from('user_profiles').insert(profileData);
    } catch (e) {
      // Don't throw error - profile creation is optional
    }
  }

  /// Get current user's profile
  static Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      return await getUserProfile(user.id);
    } catch (e) {
      return null;
    }
  }

  /// Create or update user profile
  static Future<UserProfile?> createOrUpdateProfile(UserProfile profile) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .upsert(profile.toJson())
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Update profile picture (with old image cleanup)
  static Future<String?> uploadProfilePicture(String userId, File file) async {
    try {
      // First, get current profile picture URL to delete old image
      String? oldImageUrl;
      try {
        final currentProfile = await _supabase
            .from('user_profiles')
            .select('profile_pic_url')
            .eq('id', userId)
            .maybeSingle();

        oldImageUrl = currentProfile?['profile_pic_url'] as String?;
      } catch (e) {
        // Could not fetch current profile image
      }

      // Try Supabase Storage first, fallback to local storage if bucket doesn't exist
      try {
        final bytes = await file.readAsBytes();
        final fileName =
            '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await _supabase.storage.from('profile-pictures').uploadBinary(
            fileName, bytes,
            fileOptions: const FileOptions(upsert: true));

        final publicUrl =
            _supabase.storage.from('profile-pictures').getPublicUrl(fileName);

        // Update profile with new picture URL
        await _supabase
            .from('user_profiles')
            .update({'profile_pic_url': publicUrl}).eq('id', userId);

        // Delete old image from Supabase Storage if it exists
        if (oldImageUrl != null &&
            oldImageUrl.isNotEmpty &&
            oldImageUrl.startsWith('http')) {
          await _deleteOldSupabaseImage(oldImageUrl);
        }

        return publicUrl;
      } catch (storageError) {
        // Supabase Storage failed, falling back to local storage

        // Fallback to local storage
        final appDir = Directory.systemTemp;
        final localFileName =
            'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final localFile = File('${appDir.path}/$localFileName');

        // Copy the selected image to app directory
        await file.copy(localFile.path);

        // Delete old local file if it exists
        if (oldImageUrl != null &&
            oldImageUrl.isNotEmpty &&
            oldImageUrl.startsWith('/')) {
          await _deleteOldLocalImage(oldImageUrl);
        }

        // Update profile in database with local file path
        await _supabase
            .from('user_profiles')
            .update({'profile_pic_url': localFile.path}).eq('id', userId);

        return localFile.path;
      }
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  /// Delete profile picture (when user removes it)
  static Future<void> deleteProfilePicture(String userId) async {
    try {
      // First, get current profile picture URL to delete the file
      String? currentImageUrl;
      try {
        final currentProfile = await _supabase
            .from('user_profiles')
            .select('profile_pic_url')
            .eq('id', userId)
            .maybeSingle();

        currentImageUrl = currentProfile?['profile_pic_url'] as String?;
      } catch (e) {
        // Could not fetch current profile image
      }

      // Update database to remove profile picture URL
      await _supabase
          .from('user_profiles')
          .update({'profile_pic_url': null}).eq('id', userId);

      // Delete the actual image file
      if (currentImageUrl != null && currentImageUrl.isNotEmpty) {
        if (currentImageUrl.startsWith('http')) {
          // Delete from Supabase Storage
          await _deleteOldSupabaseImage(currentImageUrl);
        } else if (currentImageUrl.startsWith('/')) {
          // Delete local file
          await _deleteOldLocalImage(currentImageUrl);
        }
      }

      // Profile picture deleted successfully
    } catch (e) {
      throw Exception('Failed to delete profile picture: $e');
    }
  }

  /// Delete old image from Supabase Storage
  static Future<void> _deleteOldSupabaseImage(String imageUrl) async {
    try {
      // Extract file path from Supabase URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find the file path after 'profile-pictures'
      final bucketIndex = pathSegments.indexOf('profile-pictures');
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

        await _supabase.storage.from('profile-pictures').remove([filePath]);
      }
    } catch (e) {
      // Don't throw error - image upload was successful
    }
  }

  /// Delete old local image file
  static Future<void> _deleteOldLocalImage(String imagePath) async {
    try {
      final oldFile = File(imagePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    } catch (e) {
      // Don't throw error - image upload was successful
    }
  }

  /// Update cover photo
  static Future<String?> uploadCoverPhoto(String userId, File file) async {
    try {
      // For now, we'll store locally and return a local file path
      // This allows immediate UI update without needing Supabase storage setup
      final appDir = Directory.systemTemp;
      final localFileName =
          'cover_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final localFile = File('${appDir.path}/$localFileName');

      // Copy the selected image to app directory
      await file.copy(localFile.path);

      // Update profile in database with local file path
      await _supabase
          .from('user_profiles')
          .update({'cover_photo_url': localFile.path}).eq('id', userId);

      return localFile.path;

      /* Future Supabase Storage implementation:
      final bytes = await file.readAsBytes();
      final fileName =
          '$userId/cover_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage.from('cover-photos').uploadBinary(fileName, bytes,
          fileOptions: const FileOptions(upsert: true));

      final publicUrl =
          _supabase.storage.from('cover-photos').getPublicUrl(fileName);

      // Update profile with new cover photo URL
      await _supabase
          .from('user_profiles')
          .update({'cover_photo_url': publicUrl}).eq('id', userId);

      return publicUrl;
      */
    } catch (e) {
      throw Exception('Failed to upload cover photo: $e');
    }
  }

  /// Update last active timestamp
  static Future<void> updateLastActive(String userId) async {
    try {
      // Temporarily disabled to avoid URL errors
      return;

      /* Original code - temporarily commented out
      await _supabase
          .rpc('update_user_last_active', params: {'user_uuid': userId});
      */
    } catch (e) {
      // Error updating last active handled silently
    }
  }

  /// Search users by name or university
  static Future<List<UserProfile>> searchUsers(String query,
      {int limit = 20}) async {
    try {
      final response = await _supabase
          .from('user_profile_stats')
          .select()
          .or('name.ilike.%$query%,university.ilike.%$query%')
          .limit(limit);

      return response
          .map<UserProfile>((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================
  // USER REVIEWS OPERATIONS
  // ============================================

  /// Get reviews for a user
  static Future<List<UserReview>> getUserReviews(String userId,
      {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('user_reviews')
          .select('''
            *,
            reviewer:reviewer_id(name, profile_pic_url),
            listing:listing_id(title)
          ''')
          .eq('reviewed_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map<UserReview>((json) {
        // Flatten the nested data
        final flatJson = Map<String, dynamic>.from(json);
        if (json['reviewer'] != null) {
          flatJson['reviewer_name'] = json['reviewer']['name'];
          flatJson['reviewer_profile_pic'] =
              json['reviewer']['profile_pic_url'];
        }
        if (json['listing'] != null) {
          flatJson['listing_title'] = json['listing']['title'];
        }
        return UserReview.fromJson(flatJson);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get reviews given by a user
  static Future<List<UserReview>> getReviewsByUser(String userId,
      {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('user_reviews')
          .select('''
            *,
            reviewed:reviewed_id(name, profile_pic_url),
            listing:listing_id(title)
          ''')
          .eq('reviewer_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map<UserReview>((json) {
        final flatJson = Map<String, dynamic>.from(json);
        if (json['reviewed'] != null) {
          flatJson['reviewed_name'] = json['reviewed']['name'];
          flatJson['reviewed_profile_pic'] =
              json['reviewed']['profile_pic_url'];
        }
        if (json['listing'] != null) {
          flatJson['listing_title'] = json['listing']['title'];
        }
        return UserReview.fromJson(flatJson);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Create a new review
  static Future<UserReview?> createReview({
    required String reviewedId,
    required int rating,
    String? reviewText,
    String? listingId,
    bool isAnonymous = false,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('user_reviews')
          .insert({
            'reviewer_id': user.id,
            'reviewed_id': reviewedId,
            'listing_id': listingId,
            'rating': rating,
            'review_text': reviewText,
            'is_anonymous': isAnonymous,
          })
          .select()
          .single();

      return UserReview.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create review: $e');
    }
  }

  /// Update a review
  static Future<UserReview?> updateReview(
    String reviewId, {
    int? rating,
    String? reviewText,
    bool? isAnonymous,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (rating != null) updates['rating'] = rating;
      if (reviewText != null) updates['review_text'] = reviewText;
      if (isAnonymous != null) updates['is_anonymous'] = isAnonymous;

      final response = await _supabase
          .from('user_reviews')
          .update(updates)
          .eq('id', reviewId)
          .select()
          .single();

      return UserReview.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update review: $e');
    }
  }

  /// Delete a review
  static Future<void> deleteReview(String reviewId) async {
    try {
      await _supabase.from('user_reviews').delete().eq('id', reviewId);
    } catch (e) {
      throw Exception('Failed to delete review: $e');
    }
  }

  // ============================================
  // USER TRANSACTIONS OPERATIONS
  // ============================================

  /// Get user transactions
  static Future<List<UserTransaction>> getUserTransactions(String userId,
      {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('user_transactions')
          .select('''
            *,
            seller:seller_id(name, profile_pic_url),
            buyer:buyer_id(name, profile_pic_url),
            listing:listing_id(title, images)
          ''')
          .or('seller_id.eq.$userId,buyer_id.eq.$userId')
          .order('transaction_date', ascending: false)
          .limit(limit);

      return response.map<UserTransaction>((json) {
        final flatJson = Map<String, dynamic>.from(json);
        if (json['seller'] != null) {
          flatJson['seller_name'] = json['seller']['name'];
          flatJson['seller_profile_pic'] = json['seller']['profile_pic_url'];
        }
        if (json['buyer'] != null) {
          flatJson['buyer_name'] = json['buyer']['name'];
          flatJson['buyer_profile_pic'] = json['buyer']['profile_pic_url'];
        }
        if (json['listing'] != null) {
          flatJson['listing_title'] = json['listing']['title'];
          final images = json['listing']['images'] as List?;
          if (images != null && images.isNotEmpty) {
            flatJson['listing_image'] = images.first;
          }
        }
        return UserTransaction.fromJson(flatJson);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user sales (where user is seller)
  static Future<List<UserTransaction>> getUserSales(String userId,
      {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('user_transactions')
          .select('''
            *,
            buyer:buyer_id(name, profile_pic_url),
            listing:listing_id(title, images)
          ''')
          .eq('seller_id', userId)
          .order('transaction_date', ascending: false)
          .limit(limit);

      return response.map<UserTransaction>((json) {
        final flatJson = Map<String, dynamic>.from(json);
        if (json['buyer'] != null) {
          flatJson['buyer_name'] = json['buyer']['name'];
          flatJson['buyer_profile_pic'] = json['buyer']['profile_pic_url'];
        }
        if (json['listing'] != null) {
          flatJson['listing_title'] = json['listing']['title'];
          final images = json['listing']['images'] as List?;
          if (images != null && images.isNotEmpty) {
            flatJson['listing_image'] = images.first;
          }
        }
        return UserTransaction.fromJson(flatJson);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user purchases (where user is buyer)
  static Future<List<UserTransaction>> getUserPurchases(String userId,
      {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('user_transactions')
          .select('''
            *,
            seller:seller_id(name, profile_pic_url),
            listing:listing_id(title, images)
          ''')
          .eq('buyer_id', userId)
          .order('transaction_date', ascending: false)
          .limit(limit);

      return response.map<UserTransaction>((json) {
        final flatJson = Map<String, dynamic>.from(json);
        if (json['seller'] != null) {
          flatJson['seller_name'] = json['seller']['name'];
          flatJson['seller_profile_pic'] = json['seller']['profile_pic_url'];
        }
        if (json['listing'] != null) {
          flatJson['listing_title'] = json['listing']['title'];
          final images = json['listing']['images'] as List?;
          if (images != null && images.isNotEmpty) {
            flatJson['listing_image'] = images.first;
          }
        }
        return UserTransaction.fromJson(flatJson);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Create a new transaction
  static Future<UserTransaction?> createTransaction({
    required String sellerId,
    required String buyerId,
    required String listingId,
    required TransactionType transactionType,
    required double amount,
    String? notes,
  }) async {
    try {
      final response = await _supabase
          .from('user_transactions')
          .insert({
            'seller_id': sellerId,
            'buyer_id': buyerId,
            'listing_id': listingId,
            'transaction_type': transactionType.name,
            'amount': amount,
            'notes': notes,
          })
          .select()
          .single();

      return UserTransaction.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
    }
  }

  /// Update transaction status
  static Future<UserTransaction?> updateTransactionStatus(
    String transactionId,
    TransactionStatus status,
  ) async {
    try {
      final response = await _supabase
          .from('user_transactions')
          .update({'status': status.name})
          .eq('id', transactionId)
          .select()
          .single();

      return UserTransaction.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update transaction status: $e');
    }
  }

  // ============================================
  // USER FAVORITES OPERATIONS
  // ============================================

  /// Get user favorites
  static Future<List<String>> getUserFavorites(String userId) async {
    try {
      final response = await _supabase
          .from('user_favorites')
          .select('listing_id')
          .eq('user_id', userId);

      return response
          .map<String>((json) => json['listing_id'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Add to favorites
  static Future<void> addToFavorites(String userId, String listingId) async {
    try {
      await _supabase.from('user_favorites').insert({
        'user_id': userId,
        'listing_id': listingId,
      });
    } catch (e) {
      throw Exception('Failed to add to favorites: $e');
    }
  }

  /// Remove from favorites
  static Future<void> removeFromFavorites(
      String userId, String listingId) async {
    try {
      await _supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('listing_id', listingId);
    } catch (e) {
      throw Exception('Failed to remove from favorites: $e');
    }
  }

  /// Check if listing is favorited
  static Future<bool> isFavorited(String userId, String listingId) async {
    try {
      final response = await _supabase
          .from('user_favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('listing_id', listingId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // FCM TOKEN OPERATIONS
  // ============================================

  /// Save FCM token to user profile
  static Future<void> saveFcmToken(String fcmToken) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _supabase.from('user_profiles').update({
        'fcm_token': fcmToken,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to save FCM token: $e');
    }
  }

  /// Get FCM token for a user
  static Future<String?> getFcmToken(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle();

      return response?['fcm_token'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get FCM tokens for multiple users
  static Future<List<String>> getFcmTokens(List<String> userIds) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('fcm_token')
          .inFilter('id', userIds);

      return response
          .map<String>((json) => json['fcm_token'] as String)
          .where((token) => token.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user's last active time for chat status
  static Future<DateTime?> getUserLastActive(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('last_active')
          .eq('id', userId)
          .single();

      if (response['last_active'] != null) {
        return DateTime.parse(response['last_active']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get cached last active time (for UI display)
  static DateTime getLastActive(String userId) {
    // For now, return a simulated time
    // In a real app, you would cache this data
    return DateTime.now().subtract(const Duration(minutes: 3));
  }

  /// Listen to user status changes
  static void listenToUserStatus(
      String userId, Function(bool) onStatusChanged) {
    // For now, simulate status changes
    // In a real app, you would use Supabase Realtime
    Timer.periodic(const Duration(seconds: 30), (timer) {
      final isOnline = DateTime.now().millisecondsSinceEpoch % 60 < 30;
      onStatusChanged(isOnline);
    });
  }

  // Update user's last active time
  static Future<void> updateUserLastActive() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.rpc(
        'update_user_last_active',
        params: {'user_id': user.id},
      );
      // Updated user last active time
    } catch (e) {
      // Error updating user last active handled silently
    }
  }

  // Get user's last active status
  static Future<String> getUserLastActiveStatus(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_user_last_active_status',
        params: {'user_id': userId},
      );

      if (response != null) {
        return response.toString();
      }
      return 'Last seen unknown';
    } catch (e) {
      return 'Last seen unknown';
    }
  }

  // Get user's last active timestamp
  static Future<DateTime?> getUserLastActiveTime(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_profiles')
          .select('last_active')
          .eq('id', userId)
          .single();

      if (response['last_active'] != null) {
        return DateTime.parse(response['last_active']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
