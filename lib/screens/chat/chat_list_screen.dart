import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/conversation.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../services/network_service.dart';
import 'chat_screen.dart';
import '../profile/profile_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _isLoading = false; // Ensure we can load initially
    _loadConversations();
    _searchController.addListener(_filterConversations);

    // Periodically check network status
    _startNetworkMonitoring();
  }

  void _startNetworkMonitoring() {
    // Check network status every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _checkNetworkStatus();
        _startNetworkMonitoring(); // Continue monitoring
      }
    });
  }

  void _checkNetworkStatus() async {
    try {
      final status = await NetworkService.getDetailedNetworkStatus();
      if (mounted && !status['hasInternet']) {
        // Only show error if we don't already have one
        if (_error == null) {
          setState(() {
            _error = '🌐 Network connection lost. Please check your internet.';
          });
        }
      }
    } catch (e) {
      print('❌ Error checking network status: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check network connectivity first
      final hasInternet = await NetworkService.hasInternetConnection();
      if (!hasInternet) {
        setState(() {
          _error =
              '🌐 No internet connection. Please check your network settings.';
          _isLoading = false;
        });
        return;
      }

      final conversations = await MessageService.getConversations();

      setState(() {
        _conversations = conversations;
        _filteredConversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading conversations: $e');
      print('❌ Error type: ${e.runtimeType}');

      // Check if it's a network error
      if (NetworkService.isNetworkError(e)) {
        setState(() {
          _error = NetworkService.getErrorMessage(e);
          _isLoading = false;
        });

        // Show network status to user
        _showNetworkStatusDialog();
      } else {
        setState(() {
          _error = 'Failed to load conversations. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _filterConversations() {
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        // If no search query, show all conversations
        _filteredConversations = _conversations;
      } else {
        // If there's a search query, filter conversations
        _filteredConversations = _conversations.where((conversation) {
          final otherParticipantName = conversation.getOtherParticipantName(
                  AuthService.getCurrentUserId() ?? '') ??
              '';
          return otherParticipantName
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat('EEEE').format(dateTime); // Day name
      } else {
        return DateFormat('dd/MM/yy').format(dateTime);
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  /// Get avatar color based on user name
  Color _getAvatarColor(String name) {
    if (name.isEmpty) return AppTheme.primaryColor;

    // Generate consistent color based on name
    final colors = [
      const Color(0xFF1976D2), // Blue
      const Color(0xFF388E3C), // Green
      const Color(0xFF7B1FA2), // Purple
      const Color(0xFFD32F2F), // Red
      const Color(0xFFF57C00), // Orange
      const Color(0xFF5D4037), // Brown
      const Color(0xFF455A64), // Blue Grey
      const Color(0xFFE91E63), // Pink
    ];

    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
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

  /// Get formatted last message text for display
  String _getLastMessageDisplayText(Conversation conversation) {
    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return 'No messages yet';

    // If no last message, show default text
    if (conversation.lastMessageText == null &&
        conversation.lastMessageType == null) {
      return 'No messages yet';
    }

    // Check if the last message is from current user or other user
    final isFromCurrentUser = conversation.lastMessageSenderId == currentUserId;

    // Handle different message types
    final messageType = conversation.lastMessageType?.toLowerCase();

    if (messageType == 'image') {
      if (isFromCurrentUser) {
        return 'You sent an image';
      } else {
        return '${conversation.getOtherParticipantName(currentUserId)} sent an image';
      }
    } else if (messageType == 'listing_share') {
      if (isFromCurrentUser) {
        return 'You shared a listing';
      } else {
        return '${conversation.getOtherParticipantName(currentUserId)} shared a listing';
      }
    } else if (messageType == 'system') {
      return conversation.lastMessageText ?? 'System message';
    } else {
      // Text message
      if (isFromCurrentUser) {
        return 'You: ${conversation.lastMessageText ?? ''}';
      } else {
        return conversation.lastMessageText ?? '';
      }
    }
  }

  Widget _buildConversationTile(Conversation conversation) {
    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return const SizedBox.shrink();

    final otherParticipantName =
        conversation.getOtherParticipantName(currentUserId) ?? 'Unknown User';
    final otherParticipantAvatar =
        conversation.getOtherParticipantAvatar(currentUserId);
    final unreadCount = conversation.getUnreadCount(currentUserId);
    final hasUnread = unreadCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            GestureDetector(
              onTap: () {
                // Navigate to user's profile
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: conversation.getOtherParticipantId(currentUserId),
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 28,
                backgroundColor: _getAvatarColor(otherParticipantName),
                backgroundImage: otherParticipantAvatar != null &&
                        otherParticipantAvatar.isNotEmpty
                    ? NetworkImage(otherParticipantAvatar)
                    : null,
                child: otherParticipantAvatar == null ||
                        otherParticipantAvatar.isEmpty
                    ? Text(
                        _getInitials(otherParticipantName),
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
            if (hasUnread)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherParticipantName,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatTime(conversation.lastMessageAt),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color:
                    hasUnread ? AppTheme.primaryColor : AppTheme.textSecondary,
                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (conversation.listingTitle != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sell,
                      size: 12,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        conversation.listingTitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    _getLastMessageDisplayText(conversation),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: hasUnread
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversationId: conversation.id,
                otherUserId: conversation.getOtherParticipantId(currentUserId),
                otherUserName: otherParticipantName,
                otherUserAvatar: otherParticipantAvatar,
                listingId: conversation.listingId,
              ),
            ),
          ).then((_) {
            // Refresh conversations when returning from chat
            _loadConversations();
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start chatting with sellers by messaging them\nfrom their listings or profiles',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to marketplace
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Browse Marketplace'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show network status dialog
  void _showNetworkStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Network Issue', style: GoogleFonts.poppins()),
          ],
        ),
        content: FutureBuilder<Map<String, dynamic>>(
          future: NetworkService.getDetailedNetworkStatus(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasData) {
              final status = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Network Status:',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('• Connectivity: ${status['connectivity']}'),
                  Text(
                      '• Internet: ${status['hasInternet'] ? '✅ Available' : '❌ Unavailable'}'),
                  Text(
                      '• Server: ${status['supabaseReachable'] ? '✅ Reachable' : '❌ Unreachable'}'),
                  const SizedBox(height: 8),
                  Text(
                    NetworkService.getErrorMessage(_error ?? ''),
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ],
              );
            }

            return Text('Unable to determine network status.');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadConversations(); // Retry loading
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _filterConversations(),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // Error message with retry button
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loadConversations,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

          // Conversations list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading conversations...'),
                      ],
                    ),
                  )
                : _filteredConversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.trim().isNotEmpty
                                  ? 'No conversations found'
                                  : 'No conversations yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchController.text.trim().isNotEmpty
                                  ? 'Try adjusting your search'
                                  : 'Start a conversation with someone!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadConversations,
                        child: ListView.builder(
                          itemCount: _filteredConversations.length,
                          itemBuilder: (context, index) {
                            return _buildConversationTile(
                                _filteredConversations[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
