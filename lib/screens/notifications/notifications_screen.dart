import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';
import '../chat/chat_screen.dart';
import '../marketplace/listing_detail_screen.dart';
import '../community/event_detail_screen.dart';
import '../community/study_group_detail_screen.dart';
import '../community/forum_topic_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  String _selectedFilter = 'all';
  final List<String> _filters = ['all', 'chat', 'marketplace', 'community', 'system'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final userId = AuthService.getCurrentUserId();
      if (userId == null) return;

      // Load notifications from Supabase
      final response = await Supabase.instance.client
          .from('chat_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await NotificationService.markNotificationAsRead(notificationId);
      
      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = AuthService.getCurrentUserId();
      if (userId == null) return;

      // Mark all as read in database
      await Supabase.instance.client
          .from('chat_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      // Update local state
      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read first
    await _markAsRead(notification['id']);

    // Navigate based on notification type
    final type = notification['type'];
    final data = notification['data'] ?? {};

    switch (type) {
      case 'chat_message':
        _navigateToChat(notification);
        break;
      case 'new_listing':
        _navigateToListing(data['listing_id']);
        break;
      case 'event_update':
        _navigateToEvent(data['event_id']);
        break;
      case 'group_post':
        _navigateToStudyGroup(data['group_id']);
        break;
      case 'forum_topic':
        _navigateToForumTopic(data['topic_id']);
        break;
      default:
        // Show notification details or handle other types
        _showNotificationDetails(notification);
        break;
    }
  }

  void _navigateToChat(Map<String, dynamic> notification) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: notification['conversation_id'],
          otherUserId: notification['sender_id'],
          otherUserName: notification['sender_name'] ?? 'User',
          otherUserAvatar: notification['sender_avatar'],
        ),
      ),
    );
  }

  void _navigateToListing(String? listingId) {
    if (listingId != null) {
      // We need to fetch the listing first since ListingDetailScreen expects a Listing object
      // For now, we'll show a message that this feature needs to be implemented
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing navigation will be implemented soon'),
          backgroundColor: Colors.orange,
        ),
      );
      
      // TODO: Implement listing fetching and navigation
      // final listing = await MarketplaceService.getListingById(listingId);
      // if (listing != null) {
      //   Navigator.push(
      //     context,
      //     MaterialPageRoute(
      //       builder: (_) => ListingDetailScreen(listing: listing),
      //     ),
      //   );
      // }
    }
  }

  void _navigateToEvent(String? eventId) {
    if (eventId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: eventId),
        ),
      );
    }
  }

  void _navigateToStudyGroup(String? groupId) {
    if (groupId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudyGroupDetailScreen(groupId: groupId),
        ),
      );
    }
  }

  void _navigateToForumTopic(String? topicId) {
    if (topicId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForumTopicDetailScreen(topicId: topicId),
        ),
      );
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title'] ?? 'Notification'),
        content: Text(notification['body'] ?? 'No content available'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    if (_selectedFilter == 'all') {
      return _notifications;
    }
    return _notifications.where((notification) {
      final type = notification['type'] ?? '';
      switch (_selectedFilter) {
        case 'chat':
          return type.contains('chat') || type.contains('message');
        case 'marketplace':
          return type.contains('listing') || type.contains('transaction');
        case 'community':
          return type.contains('event') || type.contains('group') || type.contains('forum');
        case 'system':
          return type.contains('system') || type.contains('update');
        default:
          return true;
      }
    }).toList();
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat_bubble;
      case 'new_listing':
        return Icons.store;
      case 'event_update':
        return Icons.event;
      case 'group_post':
        return Icons.group;
      case 'forum_topic':
        return Icons.forum;
      case 'system_update':
        return Icons.system_update;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'chat_message':
        return Colors.blue;
      case 'new_listing':
        return Colors.green;
      case 'event_update':
        return Colors.orange;
      case 'group_post':
        return Colors.purple;
      case 'forum_topic':
        return Colors.indigo;
      case 'system_update':
        return Colors.grey;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _getFilteredNotifications();
    final unreadCount = _notifications.where((n) => !(n['is_read'] ?? false)).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        filter.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: AppTheme.primaryColor,
                      checkmarkColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Notifications List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredNotifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = filteredNotifications[index];
                            return _buildNotificationTile(notification);
                          },
                        ),
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
            Icons.notifications_none,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see notifications here when you receive them',
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

  Widget _buildNotificationTile(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? 'Notification';
    final body = notification['body'] ?? 'No content available';
    final createdAt = DateTime.tryParse(notification['created_at'] ?? '') ?? DateTime.now();
    final timeAgo = _getTimeAgo(createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isRead ? 1 : 3,
      color: isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(type),
          child: Icon(
            _getNotificationIcon(type),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
            color: isRead ? Colors.grey[700] : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              body,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              timeAgo,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () => _handleNotificationTap(notification),
        onLongPress: () => _showNotificationActions(notification),
      ),
    );
  }

  void _showNotificationActions(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Mark as read'),
              onTap: () {
                Navigator.pop(context);
                _markAsRead(notification['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteNotification(notification['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('chat_notifications')
          .delete()
          .eq('id', notificationId);

      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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