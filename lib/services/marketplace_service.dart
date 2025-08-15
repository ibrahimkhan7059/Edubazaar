import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing.dart';
import 'dart:io';

class MarketplaceService {
  static final _supabase = Supabase.instance.client;

  // Get current user ID
  static String? get currentUserId => _supabase.auth.currentUser?.id;

  // Create a new listing
  static Future<String> createListing(Listing listing) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to create listings');
    }

    try {
      // Convert listing to JSON but exclude id and auto-generated fields
      final listingData = {
        'user_id': userId, // Use authenticated user ID
        'title': listing.title,
        'description': listing.description,
        'price': listing.price,
        'type': listing.type.name,
        'category': listing.category.name,
        'condition': listing.condition?.name,
        'images': listing.images,
        'tags': listing.tags,
        'subject': listing.subject,
        'course_code': listing.courseCode,
        'university': listing.university,
        'author': listing.author,
        'isbn': listing.isbn,
        'edition': listing.edition,
        'file_url': listing.fileUrl,
        'pickup_location': listing.pickupLocation,
        'latitude': listing.latitude,
        'longitude': listing.longitude,
        'allow_shipping': listing.allowShipping,
        'status': listing.status.name,
      };

      final response = await _supabase
          .from('listings')
          .insert(listingData)
          .select('id')
          .single();

      return response['id'];
    } catch (e) {
      print('Supabase error creating listing: $e');
      throw Exception('Failed to create listing: ${e.toString()}');
    }
  }

  // Get all listings with basic filtering
  static Future<List<Listing>> getAllListings({
    int limit = 20,
    String? searchQuery,
    ListingType? type,
    ListingCategory? category,
  }) async {
    try {
      // Build the base query
      var query = _supabase
          .from('listings')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(limit);

      // Build query with type filter if needed
      if (type != null) {
        query = _supabase
            .from('listings')
            .select()
            .eq('status', 'active')
            .eq('type', type.name)
            .order('created_at', ascending: false)
            .limit(limit);
      }

      // Build query with category filter if needed (and type if both provided)
      if (category != null) {
        if (type != null) {
          query = _supabase
              .from('listings')
              .select()
              .eq('status', 'active')
              .eq('type', type.name)
              .eq('category', category.name)
              .order('created_at', ascending: false)
              .limit(limit);
        } else {
          query = _supabase
              .from('listings')
              .select()
              .eq('status', 'active')
              .eq('category', category.name)
              .order('created_at', ascending: false)
              .limit(limit);
        }
      }

      final response = await query;
      var listings =
          (response as List).map((json) => Listing.fromJson(json)).toList();

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        listings = listings.where((listing) {
          return listing.title.toLowerCase().contains(query) ||
              listing.description.toLowerCase().contains(query) ||
              listing.tags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
      }

      return listings;
    } catch (e) {
      print('Supabase error fetching listings: $e');
      throw Exception('Failed to fetch listings: ${e.toString()}');
    }
  }

  // Get single listing by ID
  static Future<Listing?> getListingById(String listingId) async {
    try {
      final response = await _supabase
          .from('listings')
          .select()
          .eq('id', listingId)
          .single();

      // Increment view count
      await _supabase.rpc('increment_listing_views', params: {
        'listing_uuid': listingId,
      });

      return Listing.fromJson(response);
    } catch (e) {
      print('Error fetching listing: $e');
      return null;
    }
  }

  // Get user's listings
  static Future<List<Listing>> getUserListings(String userId) async {
    try {
      final response = await _supabase
          .from('listings')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Listing.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch user listings: ${e.toString()}');
    }
  }

  // Get current user's listings
  static Future<List<Listing>> getMyListings() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in');
    }
    return getUserListings(userId);
  }

  // Update listing
  static Future<void> updateListing(
      String listingId, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('listings').update(updates).eq('id', listingId);
    } catch (e) {
      throw Exception('Failed to update listing: ${e.toString()}');
    }
  }

  // Delete listing (soft delete)
  static Future<void> deleteListing(String listingId) async {
    try {
      await _supabase.from('listings').update({
        'status': ListingStatus.deleted.name,
      }).eq('id', listingId);
    } catch (e) {
      throw Exception('Failed to delete listing: ${e.toString()}');
    }
  }

  // Toggle favorite
  static Future<void> toggleFavorite(String listingId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in to favorite listings');
    }

    try {
      final existing = await _supabase
          .from('favorites')
          .select()
          .eq('listing_id', listingId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('favorites')
            .delete()
            .eq('listing_id', listingId)
            .eq('user_id', userId);
      } else {
        await _supabase.from('favorites').insert({
          'listing_id': listingId,
          'user_id': userId,
        });
      }
    } catch (e) {
      throw Exception('Failed to toggle favorite: ${e.toString()}');
    }
  }

  // Check if listing is favorited by current user
  static Future<bool> isListingFavorited(String listingId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    try {
      final response = await _supabase
          .from('favorites')
          .select('id')
          .eq('listing_id', listingId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  // Get user's favorite listings
  static Future<List<Listing>> getFavoriteListings() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('User must be logged in');
    }

    try {
      final response = await _supabase.from('favorites').select('''
            listing_id,
            listings!inner(*)
          ''').eq('user_id', userId).order('created_at', ascending: false);

      return (response as List)
          .map((item) => Listing.fromJson(item['listings']))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch favorite listings: ${e.toString()}');
    }
  }

  // Upload image to Supabase storage
  static Future<String> uploadImage(File imageFile) async {
    try {
      print('📤 Starting image upload...');
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User must be logged in to upload images');
      }

      final bytes = await imageFile.readAsBytes();
      final fileName = 'listing_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$currentUserId/$fileName';

      print('🔄 Uploading to Supabase Storage: $filePath');
      await _supabase.storage.from('listing-images').uploadBinary(
          filePath, bytes,
          fileOptions: const FileOptions(upsert: true));

      // Get public URL
      final publicUrl =
          _supabase.storage.from('listing-images').getPublicUrl(filePath);

      print('✅ Image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('Image upload failed: $e');

      // If storage bucket doesn't exist, return empty string
      if (e.toString().contains('bucket') ||
          e.toString().contains('not found')) {
        print(
            'Storage bucket not found, using empty string to show default placeholder');
        return '';
      }

      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  // Get sample listings for demo (removed - using real data only)
  @Deprecated('Use getAllListings() instead')
  static List<Listing> getSampleListings() {
    return []; // Return empty - we want real data only
  }
}
