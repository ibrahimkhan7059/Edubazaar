import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../models/listing.dart';
import '../../services/marketplace_service.dart';
import '../marketplace/listing_detail_screen.dart';

class UserFavouritesScreen extends StatefulWidget {
  const UserFavouritesScreen({super.key});

  @override
  State<UserFavouritesScreen> createState() => _UserFavouritesScreenState();
}

class _UserFavouritesScreenState extends State<UserFavouritesScreen> {
  List<Listing> _favouriteListings = [];
  bool _isLoading = true;

  // Track view counts locally for real-time updates
  final Map<String, int> _viewCounts = {};

  @override
  void initState() {
    super.initState();
    _loadFavouriteListings();
  }

  Future<void> _loadFavouriteListings() async {
    setState(() => _isLoading = true);

    try {
      final favourites = await MarketplaceService.getFavoriteListings();
      setState(() {
        _favouriteListings = favourites;
        _isLoading = false;
      });

      // Initialize view counts
      _initializeViewCounts();
    } catch (e) {
      print('Error loading favourite listings: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading favourites: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadFavouriteListings(),
            ),
          ),
        );
      }
    }
  }

  // Initialize view counts from listings
  void _initializeViewCounts() {
    for (final listing in _favouriteListings) {
      _viewCounts[listing.id] = listing.views;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Favourites'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (_favouriteListings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFavouriteListings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favouriteListings.isEmpty
              ? _buildEmptyState()
              : _buildFavouritesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Favourites Yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding listings to your favourites\nby tapping the heart icon',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textHint,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to home screen (which has marketplace tab)
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
            icon: const Icon(Icons.explore),
            label: const Text('Explore Marketplace'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavouritesList() {
    return RefreshIndicator(
      onRefresh: _loadFavouriteListings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favouriteListings.length,
        itemBuilder: (context, index) {
          return _buildFavouriteCard(_favouriteListings[index]);
        },
      ),
    );
  }

  Widget _buildFavouriteCard(Listing listing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListingDetailScreen(listing: listing),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.backgroundColor,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: listing.images.isNotEmpty
                      ? _buildListingImage(listing.images.first, listing.type)
                      : Container(
                          color: AppTheme.backgroundColor,
                          child: Icon(
                            _getIconForType(listing.type),
                            size: 30,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (listing.condition != null)
                      Text(
                        listing.condition!.displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          listing.isDonation
                              ? 'FREE'
                              : 'Rs. ${listing.price!.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: listing.isDonation
                                ? AppTheme.donationColor
                                : AppTheme.priceColor,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.visibility,
                              size: 14,
                              color: AppTheme.textHint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_viewCounts[listing.id] ?? listing.views}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.favorite,
                              size: 14,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${listing.favorites}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Remove from favourites button
              IconButton(
                onPressed: () => _removeFromFavourites(listing),
                icon: const Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingImage(String imageUrl, ListingType listingType) {
    try {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: 80,
        height: 80,
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
        errorWidget: (context, url, error) => Container(
          color: AppTheme.backgroundColor,
          child: Icon(
            _getIconForType(listingType),
            size: 30,
            color: AppTheme.primaryColor,
          ),
        ),
      );
    } catch (e) {
      return Container(
        color: AppTheme.backgroundColor,
        child: Icon(
          _getIconForType(listingType),
          size: 30,
          color: AppTheme.primaryColor,
        ),
      );
    }
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

  Future<void> _removeFromFavourites(Listing listing) async {
    try {
      await MarketplaceService.toggleFavorite(listing.id);

      // Remove from local list
      setState(() {
        _favouriteListings.removeWhere((item) => item.id == listing.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${listing.title}" from favourites'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await MarketplaceService.toggleFavorite(listing.id);
                  setState(() {
                    _favouriteListings.add(listing);
                  });
                } catch (e) {
                  print('Error undoing favourite removal: $e');
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error removing from favourites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
