import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  void initState() {
    super.initState();
    _loadListings();
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
    } catch (e) {
      print('Error loading listings: $e');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
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
            onChanged: (_) => _applyFilters(),
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
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Books',
                  _selectedType == ListingType.book,
                  () {
                    setState(() => _selectedType = ListingType.book);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Notes',
                  _selectedType == ListingType.notes,
                  () {
                    setState(() => _selectedType = ListingType.notes);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Equipment',
                  _selectedType == ListingType.equipment,
                  () {
                    setState(() => _selectedType = ListingType.equipment);
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Donations',
                  _showDonationsOnly,
                  () {
                    setState(() => _showDonationsOnly = !_showDonationsOnly);
                    _applyFilters();
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
          Icon(
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
      onRefresh: _loadListings,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredListings.length,
        itemBuilder: (context, index) {
          return _buildListingCard(_filteredListings[index]);
        },
      ),
    );
  }

  Widget _buildListingCard(Listing listing) {
    return GestureDetector(
      onTap: () {
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
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: const BorderRadius.only(
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
                            Icon(
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
                      child: IconButton(
                        iconSize: 18,
                        padding: const EdgeInsets.all(4),
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        icon: Icon(
                          Icons.favorite_border,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          // TODO: Toggle favorite
                        },
                      ),
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
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 3),

                    if (listing.condition != null)
                      Text(
                        listing.condition!.displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),

                    const Spacer(),

                    // Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            listing.isDonation
                                ? 'FREE'
                                : '\$${listing.price!.toStringAsFixed(0)}',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: listing.isDonation
                                  ? AppTheme.donationColor
                                  : AppTheme.priceColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility,
                                size: 11, color: AppTheme.textHint),
                            const SizedBox(width: 2),
                            Text(
                              '${listing.views}',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
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
          child: Center(
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
              valueColor: AlwaysStoppedAnimation<Color>(
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
}
