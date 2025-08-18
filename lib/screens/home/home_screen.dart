import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/message_service.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../../services/marketplace_service.dart';
import '../../services/community_service.dart';
import '../../models/user_profile.dart';
import '../../models/listing.dart';
import '../../models/event.dart';
import '../../models/study_group.dart';
import '../marketplace/marketplace_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_list_screen.dart';
import '../community/community_screen.dart';
import '../marketplace/listing_detail_screen.dart';
import '../community/event_detail_screen.dart';
import '../community/study_group_detail_screen.dart';
import '../marketplace/create_listing_screen.dart';
import '../community/create_event_screen.dart';
import '../community/create_study_group_screen.dart';
import '../test_notification_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/notification_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  int _unreadCount = 0;
  int _favoriteCount = 0;

  // Real-time data
  UserProfile? _currentUserProfile;
  String? _currentUserId;
  List<Listing> _recentListings = [];
  List<Event> _upcomingEvents = [];
  List<StudyGroup> _recentGroups = [];
  bool _isLoading = true;

  // Supabase realtime channels
  RealtimeChannel? _listingsChannel;
  RealtimeChannel? _eventsChannel;
  RealtimeChannel? _groupsChannel;
  RealtimeChannel? _favoritesChannel;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadUnreadCount();
    _subscribeToMessages();
    _updateUserStatus();

    // Initialize with some default data for immediate display
    _initializeDefaultData();
    _loadRealTimeData();

    // Subscribe to realtime changes
    _subscribeRealtime();

    // Fallback: if loading takes too long, show content anyway
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  // Initialize with default data for immediate display
  void _initializeDefaultData() {
    // Set a default user profile if none exists
    if (_currentUserProfile == null) {
      _currentUserProfile = UserProfile(
        id: 'default',
        name: 'Student',
        email: 'student@example.com',
        profilePicUrl: null,
        bio: 'Welcome to EduBazaar!',
        phoneNumber: null,
        university: 'Your University',
        course: 'Your Course',
        semester: '1',
        lastActive: DateTime.now(),
        joinedDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        totalListings: 0,
        totalSales: 0,
        averageRating: 0.0,
      );
    }
  }

  // Load real-time data for dashboard
  Future<void> _loadRealTimeData() async {
    try {
      setState(() => _isLoading = true);

      // Load current user profile
      final currentUserId = AuthService.getCurrentUserId();
      _currentUserId = currentUserId;

      if (currentUserId != null) {
        try {
          final profile = await ProfileService.getCurrentUserProfile();
          if (mounted) {
            setState(() => _currentUserProfile = profile);
          }
        } catch (e) {
          // Error loading profile handled silently
        }
      } else {
        // No current user ID found
      }

      // Load recent marketplace listings
      try {
        final listings = await MarketplaceService.getAllListings(limit: 5);
        if (mounted) {
          setState(() => _recentListings = listings);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _recentListings = []);
        }
      }

      // Load favorite listings count
      try {
        final favs = await MarketplaceService.getFavoriteListings();
        if (mounted) {
          setState(() => _favoriteCount = favs.length);
        }
      } catch (e) {
        if (mounted) setState(() => _favoriteCount = 0);
      }

      // Load upcoming events
      try {
        final events = await CommunityService.getUpcomingEvents();
        if (mounted) {
          setState(() => _upcomingEvents = events.take(2).toList());
        }
      } catch (e) {
        if (mounted) {
          setState(() => _upcomingEvents = []);
        }
      }

      // Load recent study groups
      try {
        final groups = await CommunityService.getDiscoverStudyGroups();
        if (mounted) {
          setState(() => _recentGroups = groups.take(4).toList());
        }
      } catch (e) {
        if (mounted) {
          setState(() => _recentGroups = []);
        }
      }

      // All data loading completed
    } catch (e) {
      // Critical error in _loadRealTimeData handled silently
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Update user's last active status
  Future<void> _updateUserStatus() async {
    try {
      await ProfileService.updateUserLastActive();
    } catch (e) {
      // Error updating user status handled silently
    }
  }

  // Initialize notifications
  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();

      // Get and save FCM token
      try {
        final token = await NotificationService.getDeviceToken();
        if (token != null) {
          await NotificationService.saveFCMTokenToSupabase(token);
        }
      } catch (e) {
        // Error saving FCM token handled silently
      }

      // Notifications initialized successfully
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Notifications may not work properly: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Unsubscribe realtime channels
    _listingsChannel?.unsubscribe();
    _eventsChannel?.unsubscribe();
    _groupsChannel?.unsubscribe();
    _favoritesChannel?.unsubscribe();
    super.dispose();
  }

  /// Load unread message count
  void _loadUnreadCount() async {
    try {
      final count = await MessageService.getTotalUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      // Error loading unread count handled silently
    }
  }

  /// Subscribe to real-time message updates
  void _subscribeToMessages() {
    MessageService.subscribeToConversations().listen((conversations) {
      if (mounted && _currentUserId != null) {
        setState(() {
          _unreadCount = conversations.fold(
              0, (sum, conv) => sum + conv.getUnreadCount(_currentUserId!));
        });
      }
    });
  }

  /// Get initials from user name
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';

    final nameParts = name.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    } else {
      // First letter of first name + first letter of last name
      return '${nameParts[0][0]}${nameParts[nameParts.length - 1][0]}'
          .toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              _buildAppBar(),

              // Main Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  children: [
                    _buildDashboard(),
                    _buildMarketplace(),
                    _buildCommunity(),
                    _buildProfile(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.school,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EduBazaar',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              Text(
                'Welcome back!',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Notifications Badge
          NotificationBadge(
            icon: Icons.notifications_outlined,
            iconSize: 28,
            iconColor: AppTheme.primaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
            tooltip: 'Notifications',
          ),

          const SizedBox(width: 8),

          // Messages Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatListScreen(),
                    ),
                  ).then((_) {
                    _loadUnreadCount();
                  });
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadRealTimeData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loading state
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading your dashboard...'),
                    ],
                  ),
                ),
              )
            else if (_recentListings.isEmpty &&
                _upcomingEvents.isEmpty &&
                _recentGroups.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No data available',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull down to refresh or check your connection',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadRealTimeData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Welcome Card with real user data
              _buildWelcomeCard(),

              const SizedBox(height: 20),

              // Quick Actions with real functionality
              _buildQuickActions(),

              const SizedBox(height: 20),

              // Recent Listings (Real data)
              if (_recentListings.isNotEmpty)
                _buildRecentListings()
              else
                _buildEmptyState('Recent Listings', 'No recent listings found',
                    Icons.shopping_cart),

              const SizedBox(height: 20),

              // Upcoming Events (Real data)
              if (_upcomingEvents.isNotEmpty)
                _buildUpcomingEvents()
              else
                _buildEmptyState(
                    'Upcoming Events', 'No upcoming events found', Icons.event),

              const SizedBox(height: 20),

              // Recent Study Groups (Real data)
              if (_recentGroups.isNotEmpty)
                _buildRecentStudyGroups()
              else
                _buildEmptyState(
                    'Study Groups', 'No study groups found', Icons.groups),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final userName = _currentUserProfile?.name ?? 'Student';
    final totalListings = _currentUserProfile?.totalListings ?? 0;
    final favs = _favoriteCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, $userName!',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your student marketplace & learning community',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildWelcomeStats('Listings', totalListings.toString()),
              const SizedBox(width: 20),
              _buildWelcomeStats('Favourites', favs.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStats(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildActionCard(
                    'Buy Books', Icons.shopping_cart, Colors.blue, () {
              setState(() {
                _currentIndex = 1;
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              });
            })),
            const SizedBox(width: 12),
            Expanded(
                child: _buildActionCard('Sell Books', Icons.sell, Colors.green,
                    () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateListingScreen(),
                ),
              ).then((_) => _loadRealTimeData());
            })),
            const SizedBox(width: 12),
            Expanded(
                child: _buildActionCard(
                    'Create Event', Icons.event, Colors.orange, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateEventScreen(),
                ),
              ).then((_) => _loadRealTimeData());
            })),
            const SizedBox(width: 12),
            Expanded(
                child: _buildActionCard(
                    'Create Group', Icons.groups, Colors.purple, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateStudyGroupScreen(),
                ),
              ).then((_) => _loadRealTimeData());
            })),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplace() {
    return const MarketplaceScreen();
  }

  Widget _buildCommunity() {
    return const CommunityScreen();
  }

  Widget _buildProfile() {
    return const ProfileScreen();
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Marketplace',
          ),
          // Removed Messages option
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildRecentListings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Listings',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 1;
                  _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                });
              },
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 226,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentListings.length,
            itemBuilder: (context, index) {
              final listing = _recentListings[index];
              return _buildListingCard(listing);
            },
          ),
        ),
      ],
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
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: listing.images.isNotEmpty
                    ? Image.network(
                        listing.images.first,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.image,
                                size: 40,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            size: 40,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.condition?.name ?? 'Unknown',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rs. ${listing.price?.toStringAsFixed(2) ?? '0.00'}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Events',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 2;
                  _pageController.animateToPage(
                    2,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                });
              },
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: math.min(_upcomingEvents.length, 2),
          itemBuilder: (context, index) {
            final event = _upcomingEvents[index];
            return _buildEventCard(event);
          },
        ),
      ],
    );
  }

  Widget _buildEventCard(Event event) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(eventId: event.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                    ? Image.network(
                        event.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          child: const Icon(Icons.event,
                              color: AppTheme.primaryColor),
                        ),
                      )
                    : Container(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        child: const Icon(Icons.event,
                            color: AppTheme.primaryColor),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.startDateTime.day}/${event.startDateTime.month}/${event.startDateTime.year} • ${event.startDateTime.hour}:${event.startDateTime.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.currentAttendees} attending',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentStudyGroups() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Study Groups',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to Community and ensure Groups->Discover tab is selected
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings:
                        const RouteSettings(arguments: {'openDiscover': true}),
                    builder: (context) =>
                        const CommunityScreen(initialTabIndex: 0),
                  ),
                ).then((_) => _loadRealTimeData());
              },
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: math.min(_recentGroups.length, 4),
          itemBuilder: (context, index) {
            final group = _recentGroups[index];
            return _buildStudyGroupCard(group);
          },
        ),
      ],
    );
  }

  Widget _buildStudyGroupCard(StudyGroup group) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudyGroupDetailScreen(groupId: group.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: (group.coverImageUrl != null &&
                        group.coverImageUrl!.isNotEmpty)
                    ? Image.network(
                        group.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildGroupAvatarFallback(group),
                      )
                    : _buildGroupAvatarFallback(group),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.subject,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.memberCount} members',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatarFallback(StudyGroup group) {
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.08),
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: AppTheme.primaryColor,
        child: Text(
          _getInitials(group.name),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Realtime: subscribe to changes and refresh sections automatically
  void _subscribeRealtime() {
    final client = Supabase.instance.client;

    _listingsChannel = client.channel('home_listings_channel')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'listings',
        callback: (payload) => _reloadListings(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'listings',
        callback: (payload) => _reloadListings(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'listings',
        callback: (payload) => _reloadListings(),
      )
      ..subscribe();

    _eventsChannel = client.channel('home_events_channel')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'events',
        callback: (payload) => _reloadEvents(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'events',
        callback: (payload) => _reloadEvents(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'events',
        callback: (payload) => _reloadEvents(),
      )
      ..subscribe();

    _groupsChannel = client.channel('home_groups_channel')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'study_groups',
        callback: (payload) => _reloadStudyGroups(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'study_groups',
        callback: (payload) => _reloadStudyGroups(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'study_groups',
        callback: (payload) => _reloadStudyGroups(),
      )
      ..subscribe();

    _favoritesChannel = client.channel('home_favorites_channel')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'favorites',
        callback: (payload) => _reloadFavorites(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'favorites',
        callback: (payload) => _reloadFavorites(),
      )
      ..subscribe();
  }

  Future<void> _reloadListings() async {
    try {
      final listings = await MarketplaceService.getAllListings(limit: 5);
      if (mounted) setState(() => _recentListings = listings);
    } catch (_) {}
  }

  Future<void> _reloadEvents() async {
    try {
      final events = await CommunityService.getUpcomingEvents();
      if (mounted) setState(() => _upcomingEvents = events.take(2).toList());
    } catch (_) {}
  }

  Future<void> _reloadStudyGroups() async {
    try {
      final groups = await CommunityService.getDiscoverStudyGroups();
      if (mounted) setState(() => _recentGroups = groups.take(4).toList());
    } catch (_) {}
  }

  Future<void> _reloadFavorites() async {
    try {
      final favs = await MarketplaceService.getFavoriteListings();
      if (mounted) setState(() => _favoriteCount = favs.length);
    } catch (_) {}
  }
}
