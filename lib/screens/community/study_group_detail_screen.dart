import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/study_group.dart';
import '../../models/user_profile.dart';
import '../../services/community_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme.dart';
import 'group_posts_screen.dart';
import 'group_members_screen.dart';
import 'group_settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class StudyGroupDetailScreen extends StatefulWidget {
  final String groupId;

  const StudyGroupDetailScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  State<StudyGroupDetailScreen> createState() => _StudyGroupDetailScreenState();
}

class _StudyGroupDetailScreenState extends State<StudyGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  final CommunityService _communityService = CommunityService();
  late TabController _tabController;

  StudyGroup? _group;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _posts = []; // Placeholder for posts
  bool _isLoading = true;
  String? _error;
  bool _isJoining = false;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroupDetails();
    _subscribeRealtime();
    _subscribeGroupRow();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _membersChannel?.unsubscribe();
    _groupRowChannel?.unsubscribe();
    super.dispose();
  }

  RealtimeChannel? _membersChannel;
  RealtimeChannel? _groupRowChannel;

  void _subscribeRealtime() {
    try {
      final client = Supabase.instance.client;
      _membersChannel = client.channel('group_${widget.groupId}_members')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: widget.groupId,
          ),
          callback: (payload) async {
            if (mounted) {
              await _loadGroupDetails();
              await _loadMembers();
            }
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'group_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: widget.groupId,
          ),
          callback: (payload) async {
            if (mounted) {
              await _loadGroupDetails();
              await _loadMembers();
            }
          },
        )
        ..subscribe();
    } catch (e) {
      // Realtime subscription error handled silently
    }
  }

  void _subscribeGroupRow() {
    try {
      final client = Supabase.instance.client;
      _groupRowChannel = client.channel('group_${widget.groupId}_row')
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'study_groups',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.groupId,
          ),
          callback: (payload) async {
            if (mounted) {
              await _loadGroupDetails();
            }
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'study_groups',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.groupId,
          ),
          callback: (payload) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This group has been deleted'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.of(context).pop(); // Return to groups list
            }
          },
        )
        ..subscribe();
    } catch (e) {
      // Error subscribing to group row handled silently
    }
  }

  Future<void> _loadGroupDetails() async {
    setState(() => _isLoading = true);
    try {
      final group = await CommunityService.getStudyGroupById(widget.groupId);

      // If group is null (deleted), navigate back
      if (group == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This group has been deleted'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      setState(() {
        _group = group;
      });

      // Load members with better error handling
      try {
        final members = await CommunityService.getGroupMembers(widget.groupId);
        setState(() {
          _members = members;
        });
      } catch (memberError) {
        // Error loading members (continuing anyway)
        // Set empty members list and continue
        setState(() {
          _members = [];
        });
      }
    } catch (e) {
      if (mounted) {
        // Don't navigate back immediately, show error but allow retry
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading group: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _loadGroupDetails(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMembers() async {
    if (_group == null) return;

    try {
      final members = await CommunityService.getGroupMembers(widget.groupId);
      if (mounted) {
        setState(() {
          _members = members;
        });

        // Member count validation
        if (_group?.memberCount != members.length) {
          // Member count mismatch - this is handled by the UI display
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _members = []; // Set empty list on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading members: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _loadMembers(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadPosts() async {
    if (_group == null) return;

    try {
      // Posts functionality to be implemented in future
    } catch (e) {
      // Error loading posts handled silently
    }
  }

  Future<void> _joinGroup() async {
    if (_group == null) return;

    setState(() {
      _isJoining = true;
    });

    try {
      await CommunityService.joinStudyGroup(widget.groupId);
      if (mounted) {
        // Refresh group details and members after joining
        await _loadGroupDetails();
        await _loadMembers();
        setState(() {
          _isJoining = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the group!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join group: $e')),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    if (_group == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLeaving = true;
    });

    try {
      await CommunityService.leaveStudyGroup(widget.groupId);
      if (mounted) {
        // Refresh group details and members after leaving
        await _loadGroupDetails();
        await _loadMembers();
        setState(() {
          _isLeaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Left the group successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLeaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _group == null
                  ? const Center(child: Text('Group not found'))
                  : _buildGroupDetail(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadGroupDetails,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupDetail() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor:
                  Colors.black12, // Semi-transparent black for visibility
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.light,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildGroupHeader(),
            ),
            actions: [
              if (_group?.role == 'admin')
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'settings') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GroupSettingsScreen(group: _group!),
                        ),
                      ).then((result) {
                        if (result == true) {
                          _loadGroupDetails();
                        }
                      });
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings),
                          SizedBox(width: 8),
                          Text('Group Settings'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ];
      },
      body: Column(
        children: [
          // Action Buttons
          _buildActionButtons(),

          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Posts'),
              Tab(text: 'Members'),
              Tab(text: 'About'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                GroupPostsScreen(
                  groupId: widget.groupId,
                  groupName: _group?.name ?? 'Group',
                ),
                _buildMembersTab(),
                _buildAboutTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader() {
    // Get status bar height to ensure background doesn't extend behind it
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // Semi-transparent status bar area for better visibility
        Container(
          height: statusBarHeight,
          color: Colors.black.withOpacity(0.3), // Darker for better visibility
        ),
        // Main content area
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              // Default gradient when no image is set
              gradient: (_group?.coverImageUrl == null ||
                      _group!.coverImageUrl!.isEmpty)
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.8),
                        AppTheme.primaryColor.withOpacity(0.6),
                      ],
                    )
                  : null,
            ),
            child: Stack(
              children: [
                // Background Image
                if (_group?.coverImageUrl != null &&
                    _group!.coverImageUrl!.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      _group!.coverImageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.8),
                                AppTheme.primaryColor.withOpacity(0.6),
                              ],
                            ),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.primaryColor.withOpacity(0.8),
                                AppTheme.primaryColor.withOpacity(0.6),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 64,
                              color: Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Semi-transparent overlay for better text visibility
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _group?.name ?? 'Unknown Group',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black38,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _group?.subject ?? 'General',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black38,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.people,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_members.length} members',
                            style: const TextStyle(
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black38,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            _group?.isPrivate == true
                                ? Icons.lock
                                : Icons.public,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _group?.isPrivate == true ? 'Private' : 'Public',
                            style: const TextStyle(
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black38,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    // Don't show any action buttons if user is admin
    if (_group?.role == 'admin') {
      return const SizedBox.shrink();
    }

    // For members - show leave button
    if (_group?.isMember == true) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLeaving ? null : _leaveGroup,
                icon: _isLeaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.exit_to_app),
                label: Text(_isLeaving ? 'Leaving...' : 'Leave Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // For non-members - show join button (if public) or private message
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _group?.isPrivate == true
                ? ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.lock),
                    label: const Text('Private Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isJoining ? null : _joinGroup,
                    icon: _isJoining
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isJoining ? 'Joining...' : 'Join Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _group?.description ?? 'No description available.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Tags
          if (_group?.tags != null && _group!.tags!.isNotEmpty) ...[
            const Text(
              'Tags',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _group!.tags!.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor:
                      Theme.of(context).primaryColor.withOpacity(0.1),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Group Info
          const Text(
            'Group Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Subject', _group?.subject ?? 'General'),
          _buildInfoRow('Members',
              '${_group?.memberCount ?? 0}/${_group?.maxMembers ?? '∞'}'),
          _buildInfoRow(
              'Type', _group?.isPrivate == true ? 'Private' : 'Public'),
          _buildInfoRow('Created', _formatDate(_group?.createdAt)),
          if (_group?.role != null) _buildInfoRow('Your Role', _group!.role!),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return Column(
      children: [
        // Header with member count and manage button
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Icon(Icons.people, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                '${_members.length} member${_members.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_group?.role == 'admin')
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            GroupMembersScreen(group: _group!),
                      ),
                    ).then(
                        (_) => _loadGroupDetails()); // Refresh after returning
                  },
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('Manage'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),

        // Members list
        Expanded(
          child: _members.isEmpty
              ? const Center(
                  child: Text('No members found'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _getProfileImageUrl(member) != null
                            ? NetworkImage(_getProfileImageUrl(member)!)
                            : null,
                        child: _getProfileImageUrl(member) == null
                            ? Text(
                                _getFirstLetter(member['name']),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                      title: Text(member['name']!),
                      subtitle: Text(member['email'] ?? ''),
                      trailing: member['user_id'] == _group?.creatorId ||
                              member['role'] == 'admin'
                          ? const Text(
                              'Admin',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is DateTime) {
      return '${date.day}/${date.month}/${date.year}';
    }
    if (date is String) {
      try {
        final dateTime = DateTime.parse(date);
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } catch (e) {
        return date;
      }
    }
    return date.toString();
  }

  // Helper method to get profile image URL from member data
  String? _getProfileImageUrl(Map<String, dynamic> member) {
    final profilePicUrl = member['profilePicUrl'] ?? member['profile_pic_url'];
    if (profilePicUrl != null && profilePicUrl.toString().isNotEmpty) {
      return profilePicUrl.toString();
    }
    return null;
  }

  // Helper method to get first letter of name for default avatar
  String _getFirstLetter(dynamic name) {
    if (name != null && name.toString().isNotEmpty) {
      return name.toString().substring(0, 1).toUpperCase();
    }
    return 'U';
  }
}
