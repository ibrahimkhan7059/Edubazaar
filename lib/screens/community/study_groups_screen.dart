import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/study_group.dart';
import '../../services/community_service.dart';
import '../../services/auth_service.dart';
import 'create_study_group_screen.dart';
import 'study_group_detail_screen.dart';

class StudyGroupsScreen extends StatefulWidget {
  const StudyGroupsScreen({super.key});

  @override
  State<StudyGroupsScreen> createState() => _StudyGroupsScreenState();
}

class _StudyGroupsScreenState extends State<StudyGroupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StudyGroup> _myGroups = [];
  List<StudyGroup> _discoverGroups = [];
  bool _isLoadingMyGroups = true;
  bool _isLoadingDiscoverGroups = true;
  RealtimeChannel? _membersChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // If a route argument requests Discover, switch to it on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['openDiscover'] == true) {
        _tabController.index = 1; // Discover tab
      }
    });

    _loadGroups();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _membersChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    try {
      final client = Supabase.instance.client;
      
      // Subscribe to group changes
      _membersChannel = client.channel('study_groups_channel')
        // Listen for new groups
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'study_groups',
          callback: (payload) {
            if (mounted) _loadGroups();
          },
        )
        // Listen for group updates
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'study_groups',
          callback: (payload) {
            if (mounted) _loadGroups();
          },
        )
        // Listen for group deletions
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'study_groups',
          callback: (payload) {
            if (mounted) _loadGroups();
          },
        )
        // Listen for member changes
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_members',
          callback: (payload) {
            if (mounted) _loadGroups();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'group_members',
          callback: (payload) {
            if (mounted) _loadGroups();
          },
        )
        // Listen for group posts
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'group_posts',
          callback: (payload) {
            if (mounted) _loadGroups();
          },
        )
        ..subscribe();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error subscribing to updates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadGroups() async {
    await Future.wait([
      _loadMyGroups(),
      _loadDiscoverGroups(),
    ]);
  }

  Future<void> _loadMyGroups() async {
    if (!mounted) return;
    
    setState(() => _isLoadingMyGroups = true);
    
    try {
      final groups = await CommunityService.getMyStudyGroups();
      if (!mounted) return;
      
      setState(() {
        _myGroups = groups;
        _isLoadingMyGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading my groups: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoadingMyGroups = false);
    }
  }

  Future<void> _loadDiscoverGroups() async {
    if (!mounted) return;
    
    setState(() => _isLoadingDiscoverGroups = true);
    
    try {
      final groups = await CommunityService.getDiscoverStudyGroups();
      if (!mounted) return;
      
      setState(() {
        _discoverGroups = groups;
        _isLoadingDiscoverGroups = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading discover groups: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoadingDiscoverGroups = false);
    }
  }

  Future<void> _refreshGroups() async {
    await _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(25),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'My Groups'),
                Tab(text: 'Discover'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: Container(
              color: AppTheme.backgroundColor,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyGroupsTab(),
                  _buildDiscoverTab(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateStudyGroupScreen(),
            ),
          );

          if (result == true) {
            // Refresh groups after creating a new one
            _refreshGroups();
          }
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    if (_isLoadingMyGroups) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_myGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Groups Yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first study group to get started!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateStudyGroupScreen(),
                  ),
                );

                if (result == true) {
                  _refreshGroups();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshGroups,
      child: Container(
        color: AppTheme.backgroundColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _myGroups.length,
          itemBuilder: (context, index) {
            final group = _myGroups[index];
            return _buildGroupCard(group, true);
          },
        ),
      ),
    );
  }

  Widget _buildDiscoverTab() {
    if (_isLoadingDiscoverGroups) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_discoverGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Groups to Discover',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new study groups!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshGroups,
      child: Container(
        color: AppTheme.backgroundColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _discoverGroups.length,
          itemBuilder: (context, index) {
            final group = _discoverGroups[index];
            return _buildGroupCard(group, false);
          },
        ),
      ),
    );
  }

  Widget _buildGroupCard(StudyGroup group, bool isMyGroup) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudyGroupDetailScreen(groupId: group.id),
            ),
          );

          if (result == true) {
            // Refresh groups if something changed
            _refreshGroups();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            if (group.coverImageUrl != null && group.coverImageUrl!.isNotEmpty)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: group.coverImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.group,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
              ),

            // Group Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isMyGroup)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            group.role ?? 'Member',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    group.description,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        group.subject,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.people,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${group.memberCount}/${group.maxMembers}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        group.isPrivate ? Icons.lock : Icons.public,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        group.isPrivate ? 'Private' : 'Public',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (group.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: group.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#$tag',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
