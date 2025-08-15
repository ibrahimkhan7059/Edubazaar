import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/listing.dart';
import '../../services/marketplace_service.dart';
import '../../services/auth_service.dart';
import '../marketplace/create_listing_screen.dart';
import '../marketplace/listing_detail_screen.dart';

class UserListingsScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserListingsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserListingsScreen> createState() => _UserListingsScreenState();
}

class _UserListingsScreenState extends State<UserListingsScreen>
    with SingleTickerProviderStateMixin {
  List<Listing> _allListings = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, active, sold, inactive
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  final List<String> _filterTabs = ['All', 'Active', 'Sold', 'Inactive'];
  bool _isCurrentUser = false;

  // Track view counts locally for real-time updates
  final Map<String, int> _viewCounts = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filterTabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedFilter =
              ['all', 'active', 'sold', 'inactive'][_tabController.index];
        });
      }
    });
    _checkIfCurrentUser();
    _loadUserListings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _checkIfCurrentUser() {
    final currentUserId = AuthService.getCurrentUserId();
    _isCurrentUser = currentUserId == widget.userId;
  }

  Future<void> _loadUserListings() async {
    setState(() => _isLoading = true);

    try {
      print(
          '🔍 Loading listings for user: ${widget.userId} (${widget.userName})');
      print('🔍 Is current user: $_isCurrentUser');

      _allListings = await MarketplaceService.getUserListings(widget.userId);
      print('✅ Loaded ${_allListings.length} listings for user');

      // Initialize view counts
      _initializeViewCounts();
    } catch (e) {
      print('❌ Error loading user listings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading listings: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadUserListings,
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Initialize view counts from listings
  void _initializeViewCounts() {
    for (final listing in _allListings) {
      _viewCounts[listing.id] = listing.views;
    }
  }

  Future<void> _updateListingStatus(
      Listing listing, ListingStatus newStatus) async {
    try {
      await MarketplaceService.updateListing(listing.id, {
        'status': newStatus.name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Update local list
      final index = _allListings.indexWhere((l) => l.id == listing.id);
      if (index != -1) {
        setState(() {
          _allListings[index] = Listing(
            id: listing.id,
            userId: listing.userId,
            title: listing.title,
            description: listing.description,
            price: listing.price,
            type: listing.type,
            category: listing.category,
            condition: listing.condition,
            images: listing.images,
            tags: listing.tags,
            subject: listing.subject,
            courseCode: listing.courseCode,
            university: listing.university,
            author: listing.author,
            isbn: listing.isbn,
            edition: listing.edition,
            fileUrl: listing.fileUrl,
            pickupLocation: listing.pickupLocation,
            allowShipping: listing.allowShipping,
            status: newStatus,
            createdAt: listing.createdAt,
            updatedAt: DateTime.now(),
            views: listing.views,
            favorites: listing.favorites,
          );
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Listing status updated to ${newStatus.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _deleteListing(Listing listing) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text(
            'Are you sure you want to delete "${listing.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await MarketplaceService.deleteListing(listing.id);

      // Remove from local list
      setState(() {
        _allListings.removeWhere((l) => l.id == listing.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting listing: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showQuickActions(Listing listing) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quick Actions',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Mark as Sold/Active toggle
            if (listing.status == ListingStatus.active)
              _buildActionButton(
                icon: Icons.check_circle,
                label: 'Mark as Sold',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _updateListingStatus(listing, ListingStatus.sold);
                },
              )
            else if (listing.status == ListingStatus.sold)
              _buildActionButton(
                icon: Icons.refresh,
                label: 'Mark as Available',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _updateListingStatus(listing, ListingStatus.active);
                },
              ),

            const SizedBox(height: 12),

            // Mark as Inactive/Active toggle
            if (listing.status != ListingStatus.inactive)
              _buildActionButton(
                icon: Icons.pause_circle,
                label: 'Mark as Inactive',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _updateListingStatus(listing, ListingStatus.inactive);
                },
              )
            else
              _buildActionButton(
                icon: Icons.play_circle,
                label: 'Mark as Active',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _updateListingStatus(listing, ListingStatus.active);
                },
              ),

            const SizedBox(height: 12),

            // Edit Listing
            _buildActionButton(
              icon: Icons.edit,
              label: 'Edit Listing',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to edit listing screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Edit functionality coming soon!'),
                    backgroundColor: AppTheme.infoColor,
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Delete Listing
            _buildActionButton(
              icon: Icons.delete,
              label: 'Delete Listing',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteListing(listing);
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isCurrentUser ? 'My Listings' : '${widget.userName}\'s Listings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          if (_isCurrentUser)
            IconButton(
              icon: const Icon(Icons.add, color: AppTheme.primaryColor),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateListingScreen(),
                  ),
                );
                if (result == true) {
                  _loadUserListings(); // Refresh listings
                }
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search listings...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),

              // Filter Tabs
              TabBar(
                controller: _tabController,
                onTap: (index) {
                  // TabBarView will handle the switching automatically
                  setState(() {
                    _selectedFilter =
                        ['all', 'active', 'sold', 'inactive'][index];
                  });
                },
                indicatorColor: AppTheme.primaryColor,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                tabs: _filterTabs.map((filter) => Tab(text: filter)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : Column(
              children: [
                _buildStatsRow(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListingsTab('all'),
                      _buildListingsTab('active'),
                      _buildListingsTab('sold'),
                      _buildListingsTab('inactive'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildListingsTab(String filterType) {
    List<Listing> tabListings = _getFilteredListings(filterType);

    if (tabListings.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadUserListings,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: tabListings.length,
        itemBuilder: (context, index) => _buildListingCard(tabListings[index]),
      ),
    );
  }

  List<Listing> _getFilteredListings(String filterType) {
    List<Listing> filtered = List.from(_allListings);

    // Apply status filter
    if (filterType != 'all') {
      filtered = filtered.where((listing) {
        switch (filterType) {
          case 'active':
            return listing.status == ListingStatus.active;
          case 'sold':
            return listing.status == ListingStatus.sold;
          case 'inactive':
            return listing.status == ListingStatus.inactive;
          default:
            return true;
        }
      }).toList();
    }

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((listing) {
        return listing.title.toLowerCase().contains(searchQuery) ||
            listing.description.toLowerCase().contains(searchQuery) ||
            listing.tags.any((tag) => tag.toLowerCase().contains(searchQuery));
      }).toList();
    }

    return filtered;
  }

  Widget _buildStatsRow() {
    final activeCount =
        _allListings.where((l) => l.status == ListingStatus.active).length;
    final soldCount =
        _allListings.where((l) => l.status == ListingStatus.sold).length;
    final totalViews = _allListings.fold(0, (sum, l) => sum + l.views);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', '${_allListings.length}', Icons.inventory),
          _buildStatItem('Active', '$activeCount', Icons.store),
          _buildStatItem('Sold', '$soldCount', Icons.check_circle),
          _buildStatItem('Views', '$totalViews', Icons.visibility),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildListingCard(Listing listing) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListingDetailScreen(listing: listing),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: listing.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: listing.images.first,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                          ),
                        )
                      : Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusChip(listing.status),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Price & Type
                    Row(
                      children: [
                        Text(
                          listing.isDonation
                              ? 'FREE'
                              : 'Rs. ${listing.price?.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: listing.isDonation
                                ? Colors.green
                                : AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            listing.type.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Stats Row
                    Row(
                      children: [
                        Icon(Icons.visibility,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('${_viewCounts[listing.id] ?? listing.views}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(width: 16),
                        Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('${listing.favorites}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                        const Spacer(),
                        Text(
                          _formatDate(listing.createdAt),
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Actions Button (only for current user)
              if (_isCurrentUser)
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  onPressed: () => _showQuickActions(listing),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ListingStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case ListingStatus.active:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case ListingStatus.sold:
        color = Colors.blue;
        icon = Icons.shopping_cart;
        break;
      case ListingStatus.inactive:
        color = Colors.orange;
        icon = Icons.pause_circle;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _isCurrentUser ? 'No listings yet' : 'No listings found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isCurrentUser
                ? 'Start selling your books and items!'
                : 'This user hasn\'t posted any listings yet.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          if (_isCurrentUser) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateListingScreen(),
                  ),
                );
                if (result == true) {
                  _loadUserListings();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create First Listing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return DateFormat('MMM dd').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }
}
 