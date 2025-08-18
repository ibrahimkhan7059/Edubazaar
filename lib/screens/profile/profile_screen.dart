import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../services/auth_service.dart';
import '../../services/message_service.dart';
import '../../core/theme.dart';
import 'edit_profile_screen.dart';
import 'user_listings_screen.dart';
import 'user_reviews_screen.dart';
import 'transaction_history_screen.dart';
import '../chat/chat_screen.dart';
import 'user_favourites_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // If null, shows current user's profile

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? userProfile;
  bool isLoading = true;
  bool isCurrentUser = false;
  final _supabase = Supabase.instance.client;
  bool isEditingBio = false;
  bool _isSigningOut = false;
  TextEditingController bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      final targetUserId = widget.userId ?? currentUserId;

      if (targetUserId == null) {
        throw Exception('User not logged in');
      }

      isCurrentUser = targetUserId == currentUserId;

      // Get profile with real-time stats
      final profile = await ProfileService.getUserProfile(targetUserId);
      if (profile == null) {
        // Try to create a basic profile if it doesn't exist
        final currentUser = AuthService.getCurrentUser();
        if (currentUser != null) {
          await AuthService.ensureUserProfileExists();
          // Try again after ensuring profile exists
          final retryProfile =
              await ProfileService.getUserProfile(targetUserId);
          if (retryProfile != null) {
            setState(() {
              userProfile = retryProfile;
              isLoading = false;
            });
            return;
          }
        }
        throw Exception('Profile not found and could not be created');
      }

      setState(() {
        userProfile = profile;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadUserProfile,
            ),
          ),
        );
      }
    }
  }

  /// Refresh profile data (for pull-to-refresh)
  Future<void> _refreshProfile() async {
    await _loadUserProfile();
  }

  ImageProvider? _getProfileImageProvider() {
    if (userProfile?.profilePicUrl != null &&
        userProfile!.profilePicUrl!.isNotEmpty) {
      // Check if it's a local file path
      if (userProfile!.profilePicUrl!.startsWith('/')) {
        final file = File(userProfile!.profilePicUrl!);
        if (file.existsSync()) {
          return FileImage(file);
        }
      }
      // If it's a network URL (Supabase Storage or existing users)
      else if (userProfile!.profilePicUrl!.startsWith('http')) {
        return NetworkImage(userProfile!.profilePicUrl!);
      }
    }

    return null; // Show initials
  }

  Widget _buildProfileContent() {
    if (userProfile == null) return _buildErrorState();

    return RefreshIndicator(
      onRefresh: _refreshProfile,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildProfileHeader(),
          // Statistics box removed
          _buildActionButtons(),
          _buildProfileInfo(),
          _buildMenuItems(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildProfileContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Profile not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Unable to load profile information',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadUserProfile,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    if (userProfile == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture (Centered)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: _getProfileImageProvider(),
                child: _getProfileImageProvider() == null
                    ? Text(
                        userProfile?.initials ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            // User Info (Centered)
            Text(
              userProfile?.name ?? 'Loading...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // _buildStatsSection removed

  Widget _buildActionButtons() {
    if (!isCurrentUser) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.userId != null
                      ? () async {
                          try {
                            final conversationData = await MessageService
                                .getOrCreateConversationWithUserInfo(
                              otherUserId: widget.userId!,
                            );

                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    conversationId:
                                        conversationData['conversationId'],
                                    otherUserId:
                                        conversationData['otherUserId'],
                                    otherUserName:
                                        conversationData['otherUserName'],
                                    otherUserAvatar:
                                        conversationData['otherUserAvatar'],
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Error starting conversation: ${e.toString()}'),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  icon: const Icon(Icons.message),
                  label: const Text('Message'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Phone call feature to be implemented
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildProfileInfo() {
    if (userProfile == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // About Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (isCurrentUser)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEditingBio)
                        Row(
                          children: [
                            TextButton(
                              onPressed: _cancelBioEdit,
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: _saveBio,
                              child: const Text('Save'),
                            ),
                          ],
                        )
                      else
                        TextButton.icon(
                          onPressed: () async {
                            if (userProfile != null) {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProfileScreen(
                                    userProfile: userProfile!,
                                  ),
                                ),
                              );

                              // Only reload if profile was actually updated
                              if (result == true) {
                                await _loadUserProfile();
                              }
                            }
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (userProfile?.bio != null && userProfile!.bio!.isNotEmpty)
              Text(
                userProfile!.bio!,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Text(
                isCurrentUser
                    ? 'Add a bio to tell others about yourself'
                    : 'No bio available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.email, userProfile?.email ?? ''),
            if (userProfile?.phoneNumber != null &&
                userProfile!.phoneNumber!.isNotEmpty)
              _buildInfoRow(Icons.phone, userProfile!.phoneNumber!),
            if (userProfile?.university != null &&
                userProfile!.university!.isNotEmpty)
              _buildInfoRow(Icons.school, userProfile!.university!),
            if (userProfile?.course != null && userProfile!.course!.isNotEmpty)
              _buildInfoRow(Icons.book,
                  '${userProfile!.course} - ${userProfile!.semester ?? 'Current'}'),
            if (userProfile?.interests != null &&
                userProfile!.interests.isNotEmpty)
              _buildInterests(),
            const SizedBox(height: 8),
            Text(
              'Member since ${_formatDate(userProfile!.joinedDate)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterests() {
    if (userProfile?.interests == null || userProfile!.interests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.interests, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Interests',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: userProfile!.interests.map((interest) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                interest,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMenuItems() {
    if (userProfile == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            _buildMenuItem(
              Icons.inventory_2_outlined,
              isCurrentUser
                  ? 'My Listings'
                  : '${userProfile!.name}\'s Listings',
              '${userProfile?.totalListings ?? 0} items',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserListingsScreen(
                      userId: userProfile!.id,
                      userName: userProfile!.name,
                    ),
                  ),
                );
              },
            ),
            if (isCurrentUser)
              _buildMenuItem(
                Icons.favorite,
                'My Favourites',
                'View your favourite listings',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserFavouritesScreen(),
                    ),
                  );
                },
              ),
            if (isCurrentUser)
              _buildMenuItem(
                Icons.logout,
                'Logout',
                'Sign out of your account',
                () => _showLogoutDialog(),
                isDestructive: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.red.withOpacity(0.1)
              : AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : AppTheme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_isSigningOut) return;
              setState(() => _isSigningOut = true);
              // Close the dialog first
              Navigator.of(context).pop();
              try {
                await AuthService.signOut();
                if (mounted) {
                  // Use the parent State context after dialog is closed
                  Navigator.pushNamedAndRemoveUntil(
                    this.context,
                    '/login',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSigningOut = false);
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  // Show enhanced about section in bottom sheet
  void _showEnhancedAbout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profile Information',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: _buildEnhancedAboutContent(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Enhanced about content for bottom sheet
  Widget _buildEnhancedAboutContent() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bio Section with inline editing
            _buildBioSection(),

            const SizedBox(height: 20),

            // Achievements section
            if (_hasAchievements()) _buildAchievements(),

            // Contact Information
            _buildContactInfo(),

            // Academic Information
            _buildAcademicInfo(),

            // Interests
            if (userProfile?.interests != null &&
                userProfile!.interests.isNotEmpty)
              _buildInterests(),

            // Missing info prompts for current user
            if (isCurrentUser) _buildMissingInfoPrompts(),

            const SizedBox(height: 16),

            // Go to full edit profile
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context); // Close bottom sheet
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                        userProfile: userProfile!,
                      ),
                    ),
                  );

                  // Only reload if profile was actually updated
                  if (result == true) {
                    await _loadUserProfile();
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text('Open Full Edit Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Member since
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Member since ${_formatDate(userProfile!.joinedDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Bio editing methods
  void _startBioEdit() {
    setState(() {
      isEditingBio = true;
      bioController.text = userProfile?.bio ?? '';
    });
  }

  void _cancelBioEdit() {
    setState(() {
      isEditingBio = false;
      bioController.clear();
    });
  }

  Future<void> _saveBio() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) throw Exception('User not logged in');

      // Store current profile image URL before any operations
      final currentProfilePicUrl = userProfile?.profilePicUrl;

      await _supabase
          .from('user_profiles')
          .update({'bio': bioController.text.trim()}).eq('id', userId);

      // Update only bio field while preserving ALL other data including image
      if (userProfile != null) {
        final newProfile = UserProfile(
          id: userProfile!.id,
          name: userProfile!.name,
          email: userProfile!.email,
          profilePicUrl: currentProfilePicUrl, // Explicitly preserve image URL
          coverPhotoUrl: userProfile!.coverPhotoUrl,
          university: userProfile!.university,
          course: userProfile!.course,
          semester: userProfile!.semester,
          bio: bioController.text.trim(), // Only update bio
          phoneNumber: userProfile!.phoneNumber,
          interests: userProfile!.interests,
          isVerified: userProfile!.isVerified,
          isActive: userProfile!.isActive,
          lastActive: userProfile!.lastActive,
          joinedDate: userProfile!.joinedDate,
          createdAt: userProfile!.createdAt,
          updatedAt: DateTime.now(), // Update timestamp
          totalListings: userProfile!.totalListings,
          activeListings: userProfile!.activeListings,
          soldListings: userProfile!.soldListings,
          averageRating: userProfile!.averageRating,
          totalReviews: userProfile!.totalReviews,
          totalSales: userProfile!.totalSales,
          totalPurchases: userProfile!.totalPurchases,
          totalDonationsGiven: userProfile!.totalDonationsGiven,
          totalDonationsReceived: userProfile!.totalDonationsReceived,
        );

        setState(() {
          userProfile = newProfile;
          isEditingBio = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bio updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating bio: ${e.toString()}')),
      );
    }
  }

  // Bio section widget
  Widget _buildBioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Bio',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (isCurrentUser && !isEditingBio)
              TextButton(
                onPressed: _startBioEdit,
                child: const Text('Edit', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isEditingBio)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: bioController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Tell others about yourself...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          )
        else if (userProfile?.bio != null && userProfile!.bio!.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              userProfile!.bio!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          GestureDetector(
            onTap: isCurrentUser ? _startBioEdit : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: isCurrentUser
                    ? Border.all(
                        color: Colors.grey[300]!, style: BorderStyle.solid)
                    : null,
              ),
              child: Text(
                isCurrentUser
                    ? '+ Add a bio to tell others about yourself'
                    : 'No bio available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          ),
      ],
    );
  }

  // Achievements section
  bool _hasAchievements() {
    return (userProfile?.isVerified ?? false) ||
        (userProfile?.totalSales ?? 0) > 10 ||
        (userProfile?.averageRating ?? 0) >= 4.5 ||
        (userProfile?.totalReviews ?? 0) > 50;
  }

  Widget _buildAchievements() {
    List<Widget> achievements = [];

    if (userProfile?.isVerified ?? false) {
      achievements.add(_buildAchievementBadge(
          'Verified User', Icons.verified, Colors.blue, 'Account verified'));
    }

    if ((userProfile?.totalSales ?? 0) > 10) {
      achievements.add(_buildAchievementBadge('Top Seller', Icons.star,
          Colors.amber, '${userProfile?.totalSales}+ sales'));
    }

    if ((userProfile?.averageRating ?? 0) >= 4.5 &&
        (userProfile?.totalReviews ?? 0) > 5) {
      achievements.add(_buildAchievementBadge(
          'Highly Rated',
          Icons.thumb_up,
          Colors.green,
          '${userProfile?.averageRating.toStringAsFixed(1)} stars'));
    }

    if (achievements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Achievements',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: achievements,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAchievementBadge(
      String title, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Contact information section
  Widget _buildContactInfo() {
    List<Widget> contactItems = [];

    contactItems.add(_buildInfoRow(Icons.email, userProfile?.email ?? ''));

    if (userProfile?.phoneNumber != null &&
        userProfile!.phoneNumber!.isNotEmpty) {
      contactItems.add(_buildInfoRow(Icons.phone, userProfile!.phoneNumber!));
    }

    if (contactItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.contact_page, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Contact',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...contactItems,
        const SizedBox(height: 16),
      ],
    );
  }

  // Academic information section
  Widget _buildAcademicInfo() {
    List<Widget> academicItems = [];

    if (userProfile?.university != null &&
        userProfile!.university!.isNotEmpty) {
      academicItems.add(_buildInfoRow(Icons.school, userProfile!.university!));
    }

    if (userProfile?.course != null && userProfile!.course!.isNotEmpty) {
      academicItems.add(_buildInfoRow(Icons.book,
          '${userProfile!.course} - ${userProfile!.semester ?? 'Current'}'));
    }

    if (academicItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.school, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Education',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...academicItems,
        const SizedBox(height: 16),
      ],
    );
  }

  // Missing information prompts
  Widget _buildMissingInfoPrompts() {
    List<Widget> prompts = [];

    if (userProfile?.bio == null || userProfile!.bio!.isEmpty) {
      prompts.add(_buildMissingInfoPrompt(
        'Add Bio',
        'Tell others about yourself',
        Icons.person,
        () => _startBioEdit(),
      ));
    }

    if (userProfile?.phoneNumber == null || userProfile!.phoneNumber!.isEmpty) {
      prompts.add(_buildMissingInfoPrompt(
        'Add Phone',
        'Let buyers contact you easily',
        Icons.phone,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfileScreen(userProfile: userProfile!),
          ),
        ).then((_) => _loadUserProfile()),
      ));
    }

    if (userProfile?.university == null || userProfile!.university!.isEmpty) {
      prompts.add(_buildMissingInfoPrompt(
        'Add University',
        'Connect with classmates',
        Icons.school,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditProfileScreen(userProfile: userProfile!),
          ),
        ).then((_) => _loadUserProfile()),
      ));
    }

    if (prompts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Complete your profile',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
        ),
        const SizedBox(height: 8),
        ...prompts,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMissingInfoPrompt(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
