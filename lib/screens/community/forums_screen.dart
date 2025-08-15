import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../models/forum_topic.dart';
import '../../services/community_service.dart';
import 'create_forum_topic_screen.dart';
import 'forum_topic_detail_screen.dart';

class ForumsScreen extends StatefulWidget {
  const ForumsScreen({super.key});

  @override
  State<ForumsScreen> createState() => _ForumsScreenState();
}

class _ForumsScreenState extends State<ForumsScreen> {
  List<ForumTopic> _topics = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  RealtimeChannel? _likesChannel;

  final List<String> _categories = [
    'All',
    'General Discussion',
    'Study Tips',
    'Course Help',
    'Career Advice',
    'Technology',
    'Books & Resources',
    'Events & Meetups',
  ];

  @override
  void initState() {
    super.initState();
    _loadTopics();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _likesChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    try {
      final client = Supabase.instance.client;
      _likesChannel = client.channel('forums_channel')
        // Listen for new topics
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'forum_topics',
          callback: (payload) {
            if (mounted) _loadTopics();
          },
        )
        // Listen for topic updates
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'forum_topics',
          callback: (payload) {
            if (mounted) _loadTopics();
          },
        )
        // Listen for topic deletions
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'forum_topics',
          callback: (payload) {
            if (mounted) _loadTopics();
          },
        )
        // Listen for new replies
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'forum_replies',
          callback: (payload) {
            if (mounted) _loadTopics();
          },
        )
        // Listen for reply deletions
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'forum_replies',
          callback: (payload) {
            if (mounted) _loadTopics();
          },
        )
        // Listen for topic likes
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'forum_topic_likes',
          callback: (payload) {
            if (mounted) _loadTopics();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'forum_topic_likes',
          callback: (payload) {
            if (mounted) _loadTopics();
          },
        )
        // Listen for reply likes
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'forum_reply_likes',
          callback: (payload) {
            if (mounted) _loadTopics();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'forum_reply_likes',
          callback: (payload) {
            if (mounted) _loadTopics();
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

  Future<void> _loadTopics() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final topics = await CommunityService.getForumTopics();

      if (!mounted) return;

      setState(() {
        _topics = topics;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading topics: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  List<ForumTopic> get _filteredTopics {
    if (_selectedCategory == 'All') {
      return _topics;
    }
    return _topics
        .where((topic) => topic.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadTopics,
                child: Column(
                  children: [
                    _buildCategoryFilter(),
                    Expanded(
                      child: _filteredTopics.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                16 + MediaQuery.of(context).padding.bottom,
                              ),
                              itemCount: _filteredTopics.length,
                              itemBuilder: (context, index) {
                                return _buildTopicCard(_filteredTopics[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateForumTopicScreen(),
            ),
          );
          if (result != null) {
            // Refresh topics after creating a new one
            _loadTopics();
          }
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                category,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              backgroundColor: Colors.white,
              selectedColor: AppTheme.primaryColor,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopicCard(ForumTopic topic) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForumTopicDetailScreen(topicId: topic.id),
          ),
        );
        // Refresh topics after returning from detail screen
        _loadTopics();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author row
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: (topic.authorAvatar.isNotEmpty)
                        ? NetworkImage(topic.authorAvatar)
                        : null,
                    child: topic.authorAvatar.isEmpty
                        ? Text(
                            (topic.authorName.isNotEmpty
                                    ? topic.authorName.substring(0, 1)
                                    : 'A')
                                .toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      topic.authorName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Topic Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      topic.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (topic.isPinned)
                    Icon(Icons.push_pin,
                        color: AppTheme.primaryColor, size: 16),
                  if (topic.isLocked)
                    Icon(Icons.lock, color: Colors.grey[600], size: 16),
                ],
              ),

              const SizedBox(height: 8),

              // Category and Stats
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      topic.category,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStatItem(
                              Icons.remove_red_eye, '${topic.viewCount}'),
                          _buildStatItem(
                              Icons.chat_bubble_outline, '${topic.replyCount}'),
                          _buildStatItem(
                              Icons.thumb_up_outlined, '${topic.likeCount}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Tags
              if (topic.tags != null && topic.tags!.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: topic.tags!.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // Last Activity
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatLastActivity(topic.lastReplyAt ?? topic.createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textHint),
        const SizedBox(width: 4),
        Text(
          count,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppTheme.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Topics Found',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to start a discussion!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textHint,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateForumTopicScreen(),
                ),
              );
              if (result != null) {
                _loadTopics();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Topic'),
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

  String _formatLastActivity(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
