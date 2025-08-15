import 'package:flutter/material.dart';
import 'package:edubazaar/models/forum_topic.dart';
import 'package:edubazaar/services/community_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForumTopicDetailScreen extends StatefulWidget {
  final String topicId;

  const ForumTopicDetailScreen({
    Key? key,
    required this.topicId,
  }) : super(key: key);

  @override
  State<ForumTopicDetailScreen> createState() => _ForumTopicDetailScreenState();
}

class _ForumTopicDetailScreenState extends State<ForumTopicDetailScreen> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _topicChannel;

  ForumTopic? _topic;
  List<Map<String, dynamic>> _replies = []; // Placeholder for replies
  bool _isLoading = true;
  String? _error;
  bool _isSubmittingReply = false;

  @override
  void initState() {
    super.initState();
    _loadTopicDetails();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    _topicChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    try {
      final client = Supabase.instance.client;
      _topicChannel = client.channel('topic_${widget.topicId}_channel')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'forum_replies',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'topic_id',
            value: widget.topicId,
          ),
          callback: (payload) async {
            if (mounted) await _loadReplies();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'forum_replies',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'topic_id',
            value: widget.topicId,
          ),
          callback: (payload) async {
            if (mounted) await _loadReplies();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'forum_reply_likes',
          callback: (payload) async {
            if (mounted) await _loadReplies();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'forum_reply_likes',
          callback: (payload) async {
            if (mounted) await _loadReplies();
          },
        )
        ..subscribe();
    } catch (_) {}
  }

  Future<void> _loadTopicDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final topic = await CommunityService.getForumTopicById(widget.topicId);
      if (!mounted) return;
      setState(() {
        _topic = topic;
        _isLoading = false;
      });
      if (topic != null) {
        // Increment views and load replies
        CommunityService.incrementForumTopicViewCount(widget.topicId);
        await _loadReplies();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load topic details: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReplies() async {
    if (_topic == null) return;

    try {
      final replies = await CommunityService.getTopicReplies(widget.topicId);
      if (!mounted) return;
      setState(() {
        _replies = replies;
      });
    } catch (e) {
      print('Error loading replies: $e');
    }
  }

  Future<void> _submitReply() async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() {
      _isSubmittingReply = true;
    });

    try {
      await CommunityService.addTopicReply(
          widget.topicId, _replyController.text.trim());

      if (!mounted) return;
      setState(() {
        _isSubmittingReply = false;
      });

      _replyController.clear();
      await _loadReplies();

      // Scroll to bottom to show newest reply
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply posted successfully!')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmittingReply = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post reply: $e')),
        );
      }
    }
  }

  Future<void> _likeReply(String replyId) async {
    try {
      final result = await CommunityService.toggleForumReplyLike(replyId);
      if (!mounted) return;
      setState(() {
        final replyIndex = _replies.indexWhere((r) => r['id'] == replyId);
        if (replyIndex != -1) {
          final reply = _replies[replyIndex];
          _replies[replyIndex] = {
            ...reply,
            'isLiked': result['isLiked'] as bool? ?? false,
            'likeCount': result['likeCount'] as int? ?? reply['likeCount'],
          };
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to like reply: $e')),
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
              : _topic == null
                  ? const Center(child: Text('Topic not found'))
                  : _buildTopicDetail(),
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
            onPressed: _loadTopicDetails,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicDetail() {
    return Column(
      children: [
        // App Bar
        _buildAppBar(),

        // Topic Content
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topic Header
                _buildTopicHeader(),
                const SizedBox(height: 16),

                // Topic Content
                _buildTopicContent(),
                const SizedBox(height: 24),

                // Replies Section
                _buildRepliesSection(),
              ],
            ),
          ),
        ),

        // Reply Input
        if (!_topic!.isLocked) _buildReplyInput(),
      ],
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Forums',
        style: TextStyle(fontSize: 16),
      ),
      actions: [
        if (_topic?.authorId == CommunityService.currentUserId)
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Topic'),
                    content: const Text(
                        'Are you sure you want to delete this topic?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  _deleteTopic();
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTopicHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _topic?.title ?? 'Untitled Topic',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Meta Information
            Row(
              children: [
                Icon(Icons.category, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _topic?.category ?? 'General',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_topic?.viewCount ?? 0} views',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.thumb_up, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_topic?.likeCount ?? 0} likes',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tags
            if (_topic?.tags != null && _topic!.tags!.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _topic!.tags!.map((tag) {
                  return Chip(
                    label: Text(tag),
                    backgroundColor:
                        Theme.of(context).primaryColor.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Author and Date
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (_topic?.authorAvatar.isNotEmpty == true)
                      ? NetworkImage(_topic!.authorAvatar)
                      : null,
                  child: (_topic?.authorAvatar.isEmpty == true)
                      ? Text(
                          (_topic?.authorName.isNotEmpty == true
                              ? _topic!.authorName.substring(0, 1).toUpperCase()
                              : 'A'),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _topic?.authorName ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatDate(_topic?.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
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
    );
  }

  Widget _buildTopicContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _topic?.content ?? 'No content available.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildRepliesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Replies',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_replies.length})',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_replies.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.forum_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No replies yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to reply!',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _replies.length,
            itemBuilder: (context, index) {
              final reply = _replies[index];
              return _buildReplyCard(reply);
            },
          ),
      ],
    );
  }

  Widget _buildReplyCard(Map<String, dynamic> reply) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reply Header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (reply['authorAvatar'] != null &&
                          (reply['authorAvatar'] as String).isNotEmpty)
                      ? NetworkImage(reply['authorAvatar'] as String)
                      : null,
                  child: (reply['authorAvatar'] == null ||
                          (reply['authorAvatar'] as String).isEmpty)
                      ? Text(
                          (reply['author'] as String)
                              .substring(0, 1)
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reply['author'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatDate(reply['createdAt']),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async => _likeReply(reply['id'] as String),
                  icon: Icon(
                    reply['isLiked'] == true
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: reply['isLiked'] == true ? Colors.red : null,
                    size: 20,
                  ),
                ),
                Text(
                  '${reply['likeCount']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reply Content
            Text(
              reply['content'] as String,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitReply(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSubmittingReply ? null : _submitReply,
            icon: _isSubmittingReply
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    if (date is DateTime) {
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    }
    return date.toString();
  }

  Future<void> _deleteTopic() async {
    try {
      if (_topic?.id != null) {
        await CommunityService.deleteForumTopic(_topic!.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Topic deleted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete topic: $e')),
      );
    }
  }
}
