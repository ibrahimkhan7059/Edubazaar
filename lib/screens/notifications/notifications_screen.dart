import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../chat/chat_screen.dart';
import 'notification_settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _filteredNotifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  RealtimeChannel? _notificationsChannel;

  final Map<String, String> _filterLabels = {
    'all': 'All',
    'chat': 'Messages',
    'listing': 'Listings',
    'community': 'Community',
    'system': 'System',
  };

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadNotifications();
    _subscribeToRealtimeUpdates();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  void _subscribeToRealtimeUpdates() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    print('🔄 Setting up real-time notifications for user: $userId');

    _notificationsChannel = Supabase.instance.client
        .channel('notifications_$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          print('📥 New notification received: ${payload.newRecord['title']}');
          if (mounted) {
            _handleNewNotification(payload.newRecord);
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'chat_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          print('📝 Notification updated: ${payload.newRecord?['id']}');
          if (mounted) {
            _handleNotificationUpdate(payload.newRecord);
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'chat_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (payload) {
          print('🗑️ Notification deleted: ${payload.oldRecord?['id']}');
          if (mounted) {
            _handleNotificationDelete(payload.oldRecord);
          }
        },
      )
      ..subscribe((status, error) {
        if (status == 'SUBSCRIBED') {
          print('✅ Real-time notifications subscribed successfully');
        } else if (error != null) {
          print('❌ Notification subscription error: $error');
        }
      });
  }

  void _handleNewNotification(Map<String, dynamic> newNotification) {
    setState(() {
      _notifications.insert(0, newNotification);
    });

    // Update filtered notifications automatically
    _filterNotifications();

    // Show local notification for immediate feedback
    _showLocalNotificationFeedback(newNotification);

    // Animate the new notification
    _slideController.reset();
    _slideController.forward();
  }

  void _handleNotificationUpdate(Map<String, dynamic> updatedNotification) {
    setState(() {
      final index = _notifications.indexWhere(
        (n) => n['id'] == updatedNotification['id'],
      );
      if (index != -1) {
        _notifications[index] = updatedNotification;
      }
    });

    // Update filtered notifications automatically
    _filterNotifications();
  }

  void _handleNotificationDelete(Map<String, dynamic>? deletedNotification) {
    if (deletedNotification == null) return;

    setState(() {
      _notifications.removeWhere(
        (n) => n['id'] == deletedNotification['id'],
      );
    });

    // Update filtered notifications automatically
    _filterNotifications();

    print('✅ Notification removed from list: ${deletedNotification['id']}');
  }

  void _showLocalNotificationFeedback(Map<String, dynamic> notification) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _getNotificationIcon(notification['type'] ?? ''),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${notification['title'] ?? 'New notification'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showDeleteNotificationDialog(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: AppTheme.errorColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete Notification',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this notification?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteNotification(notification['id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('chat_notifications')
          .delete()
          .eq('id', notificationId);

      // Remove from local list immediately
      setState(() {
        _notifications.removeWhere((n) => n['id'] == notificationId);
      });
      _filterNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Notification deleted'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Failed to delete notification'),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
        return;
      }

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
        _filterNotifications();
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterNotifications() {
    setState(() {
      if (_selectedFilter == 'all') {
        _filteredNotifications = _notifications;
      } else {
        _filteredNotifications = _notifications
            .where((notification) => notification['type'] == _selectedFilter)
            .toList();
      }
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      print('🔄 Marking notification as read: $notificationId');

      final result = await Supabase.instance.client
          .from('chat_notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .select()
          .single();

      print('✅ Notification marked as read: $result');

      setState(() {
        final index =
            _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });

      // Update filtered notifications
      _filterNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.mark_email_read, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Marked as read'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Failed to mark as read: ${e.toString()}'),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('❌ No user ID for mark all as read');
        return;
      }

      print('🔄 Marking all notifications as read for user: $userId');

      final result = await Supabase.instance.client
          .from('chat_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false)
          .select();

      print('✅ Updated ${result.length} notifications to read');

      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
      });

      // Update filtered notifications
      _filterNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.done_all, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                    'All notifications marked as read (${result.length} updated)'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Failed to mark all as read: ${e.toString()}'),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _notifications.where((n) => !(n['is_read'] ?? false)).length;

    print(
        '📊 Build: Total notifications: ${_notifications.length}, Unread: $unreadCount');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      // Add padding to separate status bar and app bar
      body: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          children: [
            // Custom App Bar with separation
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: AppTheme.textPrimary,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back',
                    ),
                    Icon(
                      Icons.notifications_active,
                      color: AppTheme.textPrimary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Notifications',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.tune,
                            color: AppTheme.textSecondary, size: 20),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationSettingsScreen(),
                          ),
                        );
                      },
                      tooltip: 'Settings',
                    ),
                    if (unreadCount > 0)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.done_all,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        onPressed: _markAllAsRead,
                        tooltip: 'Mark all as read ($unreadCount)',
                      ),
                  ],
                ),
              ),
            ),
            // Filter Chips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildFilterChips(),
            ),
            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredNotifications.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _filteredNotifications.length,
                            itemBuilder: (context, index) {
                              final notification =
                                  _filteredNotifications[index];
                              return _buildNotificationTile(notification);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filterLabels.entries.map((entry) {
          final isSelected = _selectedFilter == entry.key;
          final unreadCount = entry.key == 'all'
              ? _notifications.where((n) => !(n['is_read'] ?? false)).length
              : _notifications
                  .where(
                      (n) => n['type'] == entry.key && !(n['is_read'] ?? false))
                  .length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getFilterIcon(entry.key),
                    size: 16,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.value,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                  if (unreadCount > 0 && !isSelected) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = entry.key;
                });
                _filterNotifications();
              },
              selectedColor: AppTheme.primaryColor,
              backgroundColor: Colors.grey[100],
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                width: 1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.notifications_none,
                size: 80,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFilter == 'all'
                  ? 'No notifications yet'
                  : 'No ${_filterLabels[_selectedFilter]?.toLowerCase()} notifications',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you receive notifications, they\'ll appear here',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] ?? '';
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final createdAt =
        DateTime.tryParse(notification['created_at'] ?? '') ?? DateTime.now();

    // Note: Sender info is now properly handled in the title from database trigger

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead
                ? Colors.grey[200]!
                : AppTheme.primaryColor.withOpacity(0.5),
            width: isRead ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getNotificationColor(type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getNotificationIcon(type),
              color: _getNotificationColor(type),
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getNotificationColor(type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getNotificationTypeLabel(type),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getNotificationColor(type),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTimeAgo(createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () => _handleNotificationTap(notification),
          onLongPress: () => _showDeleteNotificationDialog(notification),
        ),
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    // Mark as read first
    if (!(notification['is_read'] ?? false)) {
      await _markAsRead(notification['id']);
    }

    final type = notification['type'] ?? '';

    switch (type) {
      case 'chat':
        _navigateToChat(notification);
        break;
      case 'listing':
        _navigateToListing(notification);
        break;
      case 'community':
        _navigateToCommunity(notification);
        break;
      default:
        // Show detail dialog for other notifications
        _showNotificationDetail(notification);
    }
  }

  void _navigateToChat(Map<String, dynamic> notification) async {
    final conversationId = notification['conversation_id'];
    final senderId = notification['sender_id'];

    if (conversationId == null || senderId == null) {
      print('❌ Missing conversation_id or sender_id');
      return;
    }

    // Try to get sender info from notification data first (faster)
    final notificationData = notification['data'];
    String? senderName;
    String? senderAvatar;

    if (notificationData != null && notificationData is Map) {
      senderName = notificationData['sender_name']?.toString();
      senderAvatar = notificationData['sender_avatar']?.toString();
    }

    // If we have sender info from notification data, use it directly
    if (senderName != null && senderName.isNotEmpty && senderName != 'User') {
      print('✅ Using sender info from notification data: $senderName');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              otherUserId: senderId,
              otherUserName:
                  senderName!, // Non-null assertion since we checked above
              otherUserAvatar: senderAvatar,
            ),
          ),
        );
      }
      return;
    }

    // Fallback: Get sender details from profiles table
    try {
      print('⏳ Fetching sender details from profiles table...');
      final senderResponse = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', senderId)
          .maybeSingle();

      senderName = senderResponse?['full_name'] ?? 'User';
      senderAvatar = senderResponse?['avatar_url'];

      print('✅ Fetched sender details: $senderName');

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              otherUserId: senderId,
              otherUserName: senderName ?? 'User', // Safe fallback
              otherUserAvatar: senderAvatar,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error getting sender details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open chat')),
        );
      }
    }
  }

  void _navigateToListing(Map<String, dynamic> notification) {
    final listingId = notification['listing_id'];
    if (listingId == null) return;

    // For now, just show a message. You can implement listing navigation later
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to listing: $listingId')),
    );
  }

  void _navigateToCommunity(Map<String, dynamic> notification) {
    // Navigate to community section
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigate to community')),
    );
  }

  void _showNotificationDetail(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title'] ?? 'Notification'),
        content: Text(notification['message'] ?? 'No additional details'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_bubble;
      case 'listing':
        return Icons.shopping_bag;
      case 'community':
        return Icons.people;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'all':
        return Icons.select_all;
      case 'chat':
        return Icons.chat_bubble;
      case 'listing':
        return Icons.shopping_bag;
      case 'community':
        return Icons.people;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'chat':
        return AppTheme.primaryColor;
      case 'listing':
        return AppTheme.successColor;
      case 'community':
        return AppTheme.accentColor;
      case 'system':
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getNotificationTypeLabel(String type) {
    switch (type) {
      case 'chat':
        return 'Message';
      case 'listing':
        return 'Listing';
      case 'community':
        return 'Community';
      case 'system':
        return 'System';
      default:
        return 'General';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays > 0) {
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
