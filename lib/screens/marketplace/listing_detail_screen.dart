import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/listing.dart';
import '../../services/marketplace_service.dart';
import '../../services/message_service.dart';
import '../chat/chat_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final Listing listing;

  const ListingDetailScreen({super.key, required this.listing});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  bool _isFavorited = false;
  bool _isLoading = false;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _checkIfFavorited();
  }

  Future<void> _checkIfFavorited() async {
    // TODO: Check if listing is favorited by current user
    // For now, we'll implement this later
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await MarketplaceService.toggleFavorite(widget.listing.id);
      setState(() => _isFavorited = !_isFavorited);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorited ? 'Added to favorites!' : 'Removed from favorites!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: _isFavorited ? Colors.green : Colors.grey[600],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundColor,
      child: Stack(
        children: [
          // Main Content
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Gallery
                  _buildImageSection(),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Price
                        _buildTitleSection(),

                        const SizedBox(height: 12),

                        // Details
                        _buildDetailsSection(),

                        const SizedBox(height: 12),

                        // Description
                        _buildDescriptionSection(),

                        const SizedBox(height: 12),

                        // Tags
                        if (widget.listing.tags.isNotEmpty) _buildTagsSection(),

                        const SizedBox(height: 12),

                        // Additional Info
                        _buildAdditionalInfoSection(),

                        const SizedBox(height: 12),

                        // Seller Info (coming soon)
                        // _buildSellerInfoSection(),

                        const SizedBox(height: 12),

                        // Contact Actions
                        _buildContactSection(),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Floating Action Buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Column(
              children: [
                // Favorite Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isFavorited ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorited ? Colors.red : Colors.black87,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ),
                const SizedBox(height: 8),
                // Share Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.share, color: Colors.black87),
                    onPressed: () {
                      // TODO: Implement share functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Share functionality coming soon!',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 320,
      width: double.infinity,
      color: Colors.grey[100],
      child: widget.listing.images.isNotEmpty
          ? _buildImageGallery()
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildImageGallery() {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _currentImageIndex = index);
          },
          itemCount: widget.listing.images.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: widget.listing.images[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => _buildPlaceholderImage(),
            );
          },
        ),

        // Image indicators
        if (widget.listing.images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.listing.images.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == entry.key
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          _getListingIcon(),
          size: 64,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  IconData _getListingIcon() {
    switch (widget.listing.type) {
      case ListingType.book:
        return Icons.book;
      case ListingType.notes:
        return Icons.note;
      case ListingType.equipment:
        return Icons.build;
      default:
        return Icons.inventory;
    }
  }

  Widget _buildTitleSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.mediumRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.listing.title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (widget.listing.isDonation)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.donationColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.donationColor),
                  ),
                  child: Text(
                    'FREE',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.donationColor,
                    ),
                  ),
                )
              else
                Text(
                  'Rs. ${widget.listing.price!.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.priceColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${widget.listing.views} views',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${widget.listing.favorites} favorites',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MMM dd, yyyy').format(widget.listing.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.mediumRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Type', widget.listing.type.displayName),
          _buildDetailRow('Category', widget.listing.category.displayName),
          if (widget.listing.condition != null)
            _buildDetailRow('Condition', widget.listing.condition!.displayName),
          if (widget.listing.subject != null)
            _buildDetailRow('Subject', widget.listing.subject!),
          if (widget.listing.courseCode != null)
            _buildDetailRow('Course Code', widget.listing.courseCode!),
          if (widget.listing.university != null)
            _buildDetailRow('University', widget.listing.university!),
          if (widget.listing.author != null)
            _buildDetailRow('Author', widget.listing.author!),
          if (widget.listing.edition != null)
            _buildDetailRow('Edition', widget.listing.edition!),
          if (widget.listing.isbn != null)
            _buildDetailRow('ISBN', widget.listing.isbn!),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.mediumRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.listing.description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.mediumRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tags',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.listing.tags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.mediumRadius,
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Information',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.listing.pickupLocation != null)
            _buildInfoRow(Icons.location_on, 'Pickup Location',
                widget.listing.pickupLocation!),

          // Show coordinates box with Open in Maps button
          if (widget.listing.hasCoordinates) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gps_fixed,
                          size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        '📍 Exact Location Coordinates',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openLocationInMaps(),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.listing.latitude!.toStringAsFixed(6)}, ${widget.listing.longitude!.toStringAsFixed(6)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '🗺️ Open in Maps',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.listing.fileUrl != null)
            _buildInfoRow(
                Icons.cloud_download, 'Digital File', 'Available for download'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Open location in maps app
  void _openLocationInMaps() {
    if (widget.listing.hasCoordinates) {
      final latitude = widget.listing.latitude!;
      final longitude = widget.listing.longitude!;

      // Create URL for maps app
      final url =
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

      // Launch URL
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildContactSection() {
    return Center(
      child: SizedBox(
        width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                // Get or create conversation with seller info
                final conversationData =
                    await MessageService.getOrCreateConversationWithUserInfo(
                  otherUserId: widget.listing.userId,
                  listingId: widget.listing.id,
                );

                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        conversationId: conversationData['conversationId'],
                        otherUserId: conversationData['otherUserId'],
                        otherUserName: conversationData['otherUserName'],
                        otherUserAvatar: conversationData['otherUserAvatar'],
                        listingId: widget.listing.id,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                      content:
                          Text('Error starting conversation: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                ),
              );
                }
              }
            },
            icon: const Icon(Icons.chat, size: 20),
            label: Text(
              'Message Seller',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
    );
  }
}
 