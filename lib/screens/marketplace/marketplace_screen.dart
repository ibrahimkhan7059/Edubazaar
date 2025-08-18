import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';
import '../../core/theme.dart';
import '../../models/listing.dart';
import '../../services/marketplace_service.dart';
import 'create_listing_screen.dart';
import 'listing_detail_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Listing> _listings = [];
  List<Listing> _filteredListings = [];
  bool _isLoading = false;
  ListingType? _selectedType;
  ListingCategory? _selectedCategory;
  bool _showDonationsOnly = false;

  // Track favorite status locally for immediate UI updates
  final Map<String, bool> _favoriteStatus = {};
  bool _isLoadingFavorites = false;

  // Track view counts locally for real-time updates
  final Map<String, int> _viewCounts = {};

  // Real-time subscription for views updates
  StreamSubscription<List<Map<String, dynamic>>>? _viewsSubscription;

  @override
  void initState() {
    super.initState();
    _loadListings();
    _setupRealTimeViews();
  }

  // Load favorite status for all listings
  Future<void> _loadFavoriteStatus() async {
    if (_listings.isEmpty) return;

    setState(() => _isLoadingFavorites = true);

    try {
      for (final listing in _listings) {
        final isFavorited =
            await MarketplaceService.isListingFavorited(listing.id);
        _favoriteStatus[listing.id] = isFavorited;
      }
    } catch (e) {
      // Error loading favorite status handled silently
    } finally {
      if (mounted) {
        setState(() => _isLoadingFavorites = false);
      }
    }
  }

  // Initialize view counts from listings
  void _initializeViewCounts() {
    for (final listing in _listings) {
      _viewCounts[listing.id] = listing.views;
    }
  }

  @override
  void dispose() {
    _viewsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadListings() async {
    setState(() => _isLoading = true);

    try {
      // Use the actual MarketplaceService to load listings
      _listings = await MarketplaceService.getAllListings(
        limit: 50,
        searchQuery:
            _searchController.text.isNotEmpty ? _searchController.text : null,
        type: _selectedType,
        category: _selectedCategory,
      );
      _applyFilters();
      // Initialize view counts and favorite status after listings are loaded
      _initializeViewCounts();
      await _loadFavoriteStatus();
    } catch (e) {
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Error loading listings: Please check your connection and try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadListings(),
            ),
          ),
        );
      }

      // Set empty list on error
      _listings = [];
      _applyFilters();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var filtered = List<Listing>.from(_listings);

    // Search filter
    if (_searchController.text.isNotEmpty) {
      String query = _searchController.text.toLowerCase();
      filtered = filtered.where((listing) {
        return listing.title.toLowerCase().contains(query) ||
            listing.description.toLowerCase().contains(query) ||
            listing.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    // Type filter
    if (_selectedType != null) {
      filtered =
          filtered.where((listing) => listing.type == _selectedType).toList();
    }

    // Category filter
    if (_selectedCategory != null) {
      filtered = filtered
          .where((listing) => listing.category == _selectedCategory)
          .toList();
    }

    // Donations filter
    if (_showDonationsOnly) {
      filtered = filtered.where((listing) => listing.isDonation).toList();
    }

    setState(() => _filteredListings = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      child: Stack(
        children: [
          Column(
            children: [
              // Search and Filters
              _buildSearchAndFilters(),

              // Listings
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredListings.isEmpty
                        ? _buildEmptyState()
                        : _buildListingsGrid(),
              ),
            ],
          ),

          // Floating Action Button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateListingScreen(),
                  ),
                );

                // Refresh listings if a new listing was created
                if (result == true) {
                  _loadListings();
                }
              },
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: AppTheme.textOnPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (_) {
              _applyFilters();
              _updateFilters();
            },
            decoration: InputDecoration(
              hintText: 'Search books, notes, equipment...',
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppTheme.textHint.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppTheme.textHint.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
          ),

          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'All',
                  _selectedType == null,
                  () {
                    setState(() => _selectedType = null);
                    _applyFilters();
                    _updateFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Books',
                  _selectedType == ListingType.book,
                  () {
                    setState(() => _selectedType = ListingType.book);
                    _applyFilters();
                    _updateFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Notes',
                  _selectedType == ListingType.notes,
                  () {
                    setState(() => _selectedType = ListingType.notes);
                    _applyFilters();
                    _updateFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Equipment',
                  _selectedType == ListingType.equipment,
                  () {
                    setState(() => _selectedType = ListingType.equipment);
                    _applyFilters();
                    _updateFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Donations',
                  _showDonationsOnly,
                  () {
                    setState(() => _showDonationsOnly = !_showDonationsOnly);
                    _applyFilters();
                    _updateFilters();
                  },
                  color: AppTheme.donationColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap,
      {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppTheme.primaryColor)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? AppTheme.primaryColor)
                : AppTheme.textHint.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 80,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            'No listings found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingsGrid() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadListings();
        await _refreshFavoriteStatus();
        await _refreshViewCounts();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive grid
          final double screenWidth = constraints.maxWidth;
          int crossAxisCount = 2;
          double childAspectRatio = 0.75;

          if (screenWidth > 600) {
            crossAxisCount = 3;
            childAspectRatio = 0.8;
          } else if (screenWidth < 360) {
            childAspectRatio = 0.7;
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _filteredListings.length,
            itemBuilder: (context, index) {
              return _buildListingCard(_filteredListings[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildListingCard(Listing listing) {
    return GestureDetector(
      onTap: () {
        // Increment view count locally for immediate feedback
        setState(() {
          _viewCounts[listing.id] =
              (_viewCounts[listing.id] ?? listing.views) + 1;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ListingDetailScreen(listing: listing),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 100,
              decoration: const BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  // Main image or placeholder
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: listing.images.isNotEmpty
                        ? _buildListingImage(listing.images.first, listing.type)
                        : Container(
                            width: double.infinity,
                            height: 100,
                            color: AppTheme.backgroundColor,
                            child: Center(
                              child: Icon(
                                _getIconForType(listing.type),
                                size: 35,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                  ),

                  // Multiple images indicator
                  if (listing.images.length > 1)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${listing.images.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Favorite button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: _buildFavoriteButton(listing),
                    ),
                  ),

                  // Donation badge
                  if (listing.isDonation)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.donationColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'FREE',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title with flexible height
                    Flexible(
                      flex: 3,
                      child: Text(
                        listing.title,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 2),

                    // Condition
                    if (listing.condition != null)
                      Flexible(
                        flex: 1,
                        child: Text(
                          listing.condition!.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Location with better overflow handling
                    if (listing.pickupLocation != null ||
                        listing.hasCoordinates) ...[
                      const SizedBox(height: 2),
                      Flexible(
                        flex: 1,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 10, color: AppTheme.textHint),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                listing.pickupLocation ?? 'Location available',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: AppTheme.textHint,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(flex: 1),

                    // Price and views row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Price with flexible width
                        Flexible(
                          flex: 3,
                          child: Text(
                            listing.isDonation
                                ? 'FREE'
                                : 'Rs. ${listing.price!.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: listing.isDonation
                                  ? AppTheme.donationColor
                                  : AppTheme.priceColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Views count
                        Flexible(
                          flex: 1,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility,
                                  size: 10, color: AppTheme.textHint),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  '${_viewCounts[listing.id] ?? listing.views}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    color: AppTheme.textHint,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingImage(String imageUrl, ListingType listingType) {
    // Try CachedNetworkImage first, with fallback to regular Image.network
    try {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        height: 100,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppTheme.backgroundColor,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            _buildFallbackImage(imageUrl, listingType),
      );
    } catch (e) {
      // If CachedNetworkImage fails to load, use regular Image.network
      return _buildFallbackImage(imageUrl, listingType);
    }
  }

  Widget _buildFallbackImage(String imageUrl, ListingType listingType) {
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: 100,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: AppTheme.backgroundColor,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppTheme.backgroundColor,
        child: Center(
          child: Icon(
            _getIconForType(listingType),
            size: 35,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(ListingType type) {
    switch (type) {
      case ListingType.book:
        return Icons.menu_book;
      case ListingType.notes:
        return Icons.note;
      case ListingType.pastPapers:
        return Icons.quiz;
      case ListingType.studyGuides:
        return Icons.book;
      case ListingType.equipment:
        return Icons.precision_manufacturing;
      case ListingType.other:
        return Icons.category;
    }
  }

  // Build favorite button with real-time status
  Widget _buildFavoriteButton(Listing listing) {
    final isFavorited = _favoriteStatus[listing.id] ?? false;

    return IconButton(
      iconSize: 18,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      icon: Icon(
        isFavorited ? Icons.favorite : Icons.favorite_border,
        color: isFavorited ? Colors.red : AppTheme.textSecondary,
        size: 18,
      ),
      onPressed: () => _toggleFavorite(listing),
    );
  }

  // Toggle favorite status
  Future<void> _toggleFavorite(Listing listing) async {
    try {
      // Optimistically update UI immediately
      final currentStatus = _favoriteStatus[listing.id] ?? false;
      setState(() {
        _favoriteStatus[listing.id] = !currentStatus;
      });

      // Call the service
      await MarketplaceService.toggleFavorite(listing.id);

      // Verify the actual status from server
      final actualStatus =
          await MarketplaceService.isListingFavorited(listing.id);

      // Update local state with actual server status
      if (mounted) {
        setState(() {
          _favoriteStatus[listing.id] = actualStatus;
        });

        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              actualStatus
                  ? 'Added to favorites! ❤️'
                  : 'Removed from favorites 💔',
            ),
            backgroundColor: actualStatus ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert the optimistic update on error
      if (mounted) {
        final originalStatus =
            await MarketplaceService.isListingFavorited(listing.id);
        setState(() {
          _favoriteStatus[listing.id] = originalStatus;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Update filters and refresh real-time stream
  void _updateFilters() {
    _loadListings();
  }

  // Refresh favorite status for all listings
  Future<void> _refreshFavoriteStatus() async {
    await _loadFavoriteStatus();
  }

  // Refresh view counts for all listings
  Future<void> _refreshViewCounts() async {
    try {
      for (final listing in _listings) {
        // Get updated listing data to refresh view count
        final updatedListing =
            await MarketplaceService.getListingById(listing.id);
        if (updatedListing != null) {
          setState(() {
            _viewCounts[listing.id] = updatedListing.views;
          });
        }
      }
    } catch (e) {
      // Error refreshing view counts handled silently
    }
  }

  void _setupRealTimeViews() {
    final supabase = Supabase.instance.client;
    final channel = supabase.channel('views_channel');

    // Listen to listing updates (including view count changes)
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'listings',
      callback: (payload) {
        if (payload.newRecord != null) {
          final newListing = Listing.fromJson(payload.newRecord!);
          final index =
              _listings.indexWhere((listing) => listing.id == newListing.id);
          if (index != -1) {
            setState(() {
              _listings[index] = newListing;
              // Update local view count for real-time display
              _viewCounts[newListing.id] = newListing.views;
              _applyFilters();
            });
          }
        }
      },
    );

    // Subscribe to favorites changes
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'favorites',
      callback: (payload) {
        if (payload.newRecord != null) {
          final listingId = payload.newRecord!['listing_id'] as String;
          final userId = payload.newRecord!['user_id'] as String;

          // Only update if it's the current user's favorite
          if (userId == MarketplaceService.currentUserId) {
            setState(() {
              _favoriteStatus[listingId] = true;
            });
          }
        }
      },
    );

    // Subscribe to view count changes specifically
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'listings',
      callback: (payload) {
        if (payload.newRecord != null) {
          final listingId = payload.newRecord!['id'] as String;
          final newViewCount = payload.newRecord!['views'] as int?;

          // Only update if this is a view count change and we're tracking this listing
          if (newViewCount != null && _viewCounts.containsKey(listingId)) {
            setState(() {
              _viewCounts[listingId] = newViewCount;
            });
          }
        }
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'favorites',
      callback: (payload) {
        if (payload.oldRecord != null) {
          final listingId = payload.oldRecord!['listing_id'] as String;
          final userId = payload.oldRecord!['user_id'] as String;

          // Only update if it's the current user's favorite
          if (userId == MarketplaceService.currentUserId) {
            setState(() {
              _favoriteStatus[listingId] = false;
            });
          }
        }
      },
    );

    channel.subscribe();
  }
}
