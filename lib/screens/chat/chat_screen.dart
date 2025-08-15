import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import '../../core/theme.dart';
import '../../models/message.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import '../../services/image_service.dart';
import '../profile/profile_screen.dart';
import 'image_viewer_screen.dart';
import 'dart:async'; // Added for Timer
import '../../services/profile_service.dart'; // Added for ProfileService

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? listingId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.listingId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploadingImage = false;

  // Typing indicator
  bool _isOtherUserTyping = false;
  Timer? _typingTimer;
  Timer? _otherUserTypingTimer;

  // Message search
  bool _isSearching = false;
  String _searchQuery = '';
  List<Message> _filteredMessages = [];
  int _currentSearchIndex = -1;

  // Message forwarding and reply
  Message? _replyingTo;
  bool _isForwarding = false;
  Message? _forwardingMessage;

  // User status refresh timer
  Timer? _statusRefreshTimer;
  String _currentStatus = 'Loading...';
  bool _isStatusLoading = true;

  // Message deletion
  Message? _selectedMessageForDeletion;
  bool _isDeletingMessage = false;

  // Multiple message selection
  Set<String> _selectedMessageIds = {};
  bool _isMultiSelectMode = false;

  // Real-time subscription
  StreamSubscription<List<Message>>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealTimeSubscription();
    _markAsRead();
    _startListeningToTyping();
    _loadUserStatus();
    _startStatusRefreshTimer();
    _updateCurrentUserStatus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _otherUserTypingTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  // Start timer to refresh status every 30 seconds
  void _startStatusRefreshTimer() {
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
          _loadUserStatus();
        });
      }
    });
  }

  // Load user status from Supabase
  Future<void> _loadUserStatus() async {
    try {
      setState(() {
        _isStatusLoading = true;
      });

      final status =
          await ProfileService.getUserLastActiveStatus(widget.otherUserId);

      if (mounted) {
        setState(() {
          _currentStatus = status;
          _isStatusLoading = false;
        });
      }
      print('🔄 Status loaded: $_currentStatus');
    } catch (e) {
      print('❌ Error loading user status: $e');
      if (mounted) {
        setState(() {
          _currentStatus = 'Last seen unknown';
          _isStatusLoading = false;
        });
      }
    }
  }

  // Update current user's status
  Future<void> _updateCurrentUserStatus() async {
    try {
      await ProfileService.updateUserLastActive();
      print('✅ Updated current user status');
    } catch (e) {
      print('❌ Error updating current user status: $e');
    }
  }

  // Message deletion methods
  void _selectMessageForDeletion(Message message) {
    print('🔍 Selecting message for deletion: ${message.id}');
    print('🔍 Message text: ${message.messageText}');
    print('🔍 Message type: ${message.messageType}');

    setState(() {
      _selectedMessageForDeletion = message;
      _isMultiSelectMode = false;
      _selectedMessageIds.clear();
    });
    print('🗑️ Message selected for deletion: ${message.id}');
  }

  void _clearSelectedMessage() {
    print('🔍 Clearing selected message');
    setState(() {
      _selectedMessageForDeletion = null;
      _isMultiSelectMode = false;
      _selectedMessageIds.clear();
    });
    print('✅ Cleared selected message');
  }

  // Multiple message selection methods
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedMessageIds.clear();
        _selectedMessageForDeletion = null;
      } else {
        // Clear single message selection when entering multi-select mode
        _selectedMessageForDeletion = null;
      }
    });
    print('🔄 Multi-select mode: $_isMultiSelectMode');
  }

  void _toggleMessageSelection(Message message) {
    final currentUserId = AuthService.getCurrentUserId();
    if (!message.isSentByUser(currentUserId ?? '')) return; // Only own messages

    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
    print('📝 Selected messages: ${_selectedMessageIds.length}');
  }

  void _selectAllMessages() {
    final currentUserId = AuthService.getCurrentUserId();
    final ownMessageIds = _messages
        .where((msg) => msg.isSentByUser(currentUserId ?? ''))
        .map((msg) => msg.id)
        .toSet();

    setState(() {
      _selectedMessageIds = ownMessageIds;
    });
    print('📝 Selected all messages: ${_selectedMessageIds.length}');
  }

  void _clearAllSelections() {
    setState(() {
      _selectedMessageIds.clear();
      _selectedMessageForDeletion = null;
      _isMultiSelectMode = false;
    });
    print('✅ Cleared all selections and exited multi-select mode');
  }

  Future<void> _deleteSelectedMessages() async {
    // Handle single message deletion
    if (_selectedMessageForDeletion != null) {
      await _deleteSingleMessage(_selectedMessageForDeletion!);
      return;
    }

    // Handle multiple message deletion
    if (_selectedMessageIds.isEmpty) return;

    setState(() {
      _isDeletingMessage = true;
    });

    // Store messages to delete before removing from local list
    final messagesToDelete =
        _messages.where((msg) => _selectedMessageIds.contains(msg.id)).toList();

    try {
      print('🗑️ Deleting ${messagesToDelete.length} messages...');

      // Remove from local list immediately for better UX
      setState(() {
        _messages.removeWhere((msg) => _selectedMessageIds.contains(msg.id));
        _selectedMessageIds.clear();
        _isMultiSelectMode = false;
        _selectedMessageForDeletion = null;
      });

      // Delete messages one by one
      for (final messageId in messagesToDelete.map((msg) => msg.id)) {
        await MessageService.deleteMessage(messageId);
      }

      // Clear cache and manually refresh messages to ensure consistency
      MessageService.clearMessageStreamCache(widget.conversationId);
      await Future.delayed(const Duration(milliseconds: 200));
      await MessageService.refreshMessages(widget.conversationId);

      setState(() {
        _isDeletingMessage = false;
      });

      print('✅ Messages deleted successfully');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${messagesToDelete.length} messages deleted'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error deleting messages: $e');

      // Restore messages to list if deletion failed
      setState(() {
        for (final message in messagesToDelete) {
          if (!_messages.any((msg) => msg.id == message.id)) {
            _messages.add(message);
          }
        }
        _isDeletingMessage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete messages: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteSingleMessage(Message message) async {
    setState(() {
      _isDeletingMessage = true;
    });

    try {
      print('🗑️ Deleting single message: ${message.id}');

      // Remove from local list immediately for better UX
      setState(() {
        _messages.removeWhere((msg) => msg.id == message.id);
        _selectedMessageForDeletion = null;
      });

      // Delete from database
      await MessageService.deleteMessage(message.id);

      // Clear cache and manually refresh messages to ensure consistency
      MessageService.clearMessageStreamCache(widget.conversationId);
      await Future.delayed(const Duration(milliseconds: 200));
      await MessageService.refreshMessages(widget.conversationId);

      setState(() {
        _isDeletingMessage = false;
      });

      print('✅ Single message deleted successfully');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error deleting single message: $e');

      // Restore message to list if deletion failed
      setState(() {
        if (!_messages.any((msg) => msg.id == message.id)) {
          _messages.add(message);
        }
        _isDeletingMessage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Typing indicator methods
  void _onTextChanged(String text) {
    // Send typing indicator
    MessageService.sendTypingIndicator(widget.conversationId, true);

    // Cancel previous timer
    _typingTimer?.cancel();

    // Set timer to stop typing indicator after 3 seconds
    _typingTimer = Timer(const Duration(seconds: 3), () {
      MessageService.sendTypingIndicator(widget.conversationId, false);
    });
  }

  void _startListeningToTyping() {
    // Listen for typing indicators from other user
    MessageService.listenToTypingIndicators(
      widget.conversationId,
      widget.otherUserId,
      (isTyping) {
        if (mounted) {
          setState(() {
            _isOtherUserTyping = isTyping;
          });

          // Auto-hide typing indicator after 5 seconds
          _otherUserTypingTimer?.cancel();
          if (isTyping) {
            _otherUserTypingTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  _isOtherUserTyping = false;
                });
              }
            });
          }
        }
      },
    );
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      print('📥 Loading messages for conversation: ${widget.conversationId}');

      // Validate conversation ID
      if (widget.conversationId.isEmpty) {
        throw Exception('Invalid conversation ID');
      }

      _messages = await MessageService.getMessages(widget.conversationId);
      print('✅ Loaded ${_messages.length} messages');

      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('❌ Error loading messages: $e');
      print('❌ Error type: ${e.runtimeType}');

      if (mounted) {
        String errorMessage = 'Error loading messages';

        if (e.toString().contains('conversation')) {
          errorMessage = 'Conversation not found. Please try again.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage = 'Failed to load messages: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadMessages,
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      await MessageService.markConversationAsRead(widget.conversationId);
    } catch (e) {
      print('❌ Error marking as read: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      // Clear input immediately for better UX
      _messageController.clear();

      print('📤 Sending message: $messageText');
      final message = await MessageService.sendTextMessage(
        widget.conversationId,
        messageText,
      );

      // Add message to local list
      setState(() {
        _messages.add(message);
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      print('✅ Message sent successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _messageController.text = messageText;
              },
            ),
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendImageMessage() async {
    if (_isUploadingImage) return;

    setState(() => _isUploadingImage = true);

    try {
      print('📸 Starting image selection...');

      // Show image source dialog
      final File? imageFile = await ImageService.showImageSourceDialog(context);

      if (imageFile == null) {
        print('⚠️ No image selected');
        setState(() => _isUploadingImage = false);
        return;
      }

      print('📸 Selected image: ${imageFile.path}');
      print('📊 File size: ${await imageFile.length()} bytes');

      // Show uploading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Uploading image...'),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 30), // Long duration for upload
        ),
      );

      print('☁️ Starting upload to Supabase...');

      // Upload image to Supabase
      final String imageUrl = await ImageService.uploadChatImage(imageFile);

      // Hide uploading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      print('📤 Image uploaded successfully: $imageUrl');
      print('📤 Sending image message...');

      // Send image message
      final message = await MessageService.sendImageMessage(
        widget.conversationId,
        imageUrl,
        caption: '', // No caption for now
      );

      print('✅ Image message sent: ${message.id}');

      // Add message to local list
      setState(() {
        _messages.add(message);
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      print('✅ Image message sent successfully');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image sent successfully!'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error sending image: $e');
      print('❌ Error type: ${e.runtimeType}');

      // Hide uploading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (mounted) {
        String errorMessage = 'Failed to send image';

        if (e.toString().contains('bucket')) {
          errorMessage =
              'Storage not configured. Please run FIX_IMAGE_UPLOAD.sql in Supabase.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Permission denied. Please check app permissions.';
        } else if (e.toString().contains('network')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else {
          errorMessage = 'Failed to send image: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _sendImageMessage,
            ),
          ),
        );
      }
    } finally {
      setState(() => _isUploadingImage = false);
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

  Widget _buildImageMessage(Message message, bool isMe) {
    // Create a unique hero tag that includes conversation ID to avoid conflicts
    final heroTag = 'image_${widget.conversationId}_${message.id}';

    // Don't show Hero widget if message is being deleted
    if (_isDeletingMessage && _selectedMessageIds.contains(message.id)) {
      return Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 300,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: message.attachmentUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 150,
              width: 200,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMe ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 150,
              width: 200,
              color: Colors.grey[300],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.grey[600],
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // In multi-select mode, don't use Hero widget to avoid conflicts
    if (_isMultiSelectMode) {
      return Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 300,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: message.attachmentUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 150,
              width: 200,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMe ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 150,
              width: 200,
              color: Colors.grey[300],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.grey[600],
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Normal mode - use simple image viewing without Hero widget
    return GestureDetector(
      onTap: () {
        // Only navigate to image viewer if not in multi-select mode
        if (!_isMultiSelectMode) {
          try {
            // Navigate to full-screen image viewer
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerScreen(
                  imageUrl: message.attachmentUrl!,
                  heroTag: heroTag, // Still pass for compatibility
                ),
              ),
            );
          } catch (e) {
            print('❌ Error opening image viewer: $e');
            // Fallback: show image in dialog
            _showImageDialog(message.attachmentUrl!);
          }
        }
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 300,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: message.attachmentUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 150,
              width: 200,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isMe ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 150,
              width: 200,
              color: Colors.grey[300],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.grey[600],
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Fallback method to show image in dialog
  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Image
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 300,
                  maxHeight: 400,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      width: 300,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      width: 300,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.error_outline, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Debug method to test image viewing
  void _testImageViewer(String imageUrl) {
    print('🧪 Testing image viewer for URL: $imageUrl');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            imageUrl: imageUrl,
            heroTag: 'test_image_${DateTime.now().millisecondsSinceEpoch}',
          ),
        ),
      );
      print('✅ Image viewer opened successfully');
    } catch (e) {
      print('❌ Error opening image viewer: $e');
      _showImageDialog(imageUrl);
    }
  }

  Widget _buildMessageStatusIcon(Message message) {
    switch (message.status) {
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: Colors.white.withOpacity(0.8),
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white.withOpacity(0.8),
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.blue[300],
        );
    }
  }

  Widget _buildMessageBubble(Message message) {
    final currentUserId = AuthService.getCurrentUserId();
    final isMe = message.isSentByUser(currentUserId ?? '');
    final isSearchResult = _isSearching &&
        _searchQuery.isNotEmpty &&
        message.messageText.toLowerCase().contains(_searchQuery.toLowerCase());

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Remove all avatars for cleaner look
          Flexible(
            child: Stack(
              children: [
                GestureDetector(
                  onLongPress: () {
                    print('🔍 Long press detected on message: ${message.id}');
                    print('🔍 Is my message: $isMe');
                    print('🔍 Multi-select mode: $_isMultiSelectMode');

                    // Only allow deletion of own messages
                    if (isMe) {
                      if (_isMultiSelectMode) {
                        print('🔍 Toggling message selection');
                        _toggleMessageSelection(message);
                      } else {
                        print(
                            '🔍 Enabling multi-select mode and selecting message');
                        // Enable multi-select mode and select this message
                        setState(() {
                          _isMultiSelectMode = true;
                          _selectedMessageIds.add(message.id);
                          _selectedMessageForDeletion =
                              null; // Clear single selection
                        });
                        print(
                            '🔄 Multi-select mode enabled with 1 message selected');
                      }
                    } else {
                      print('🔍 Showing reaction options');
                      _showReactionOptions(message);
                    }
                  },
                  onTap: () {
                    print('🔍 Tap detected on message: ${message.id}');
                    print('🔍 Message type: ${message.messageType}');
                    print('🔍 Multi-select mode: $_isMultiSelectMode');
                    print('🔍 Is my message: $isMe');
                    print(
                        '🔍 Selected message ID: ${_selectedMessageForDeletion?.id}');

                    if (_isMultiSelectMode) {
                      if (isMe) {
                        print(
                            '🔍 Toggling message selection in multi-select mode');
                        _toggleMessageSelection(message);

                        // If no messages selected, exit multi-select mode
                        if (_selectedMessageIds.isEmpty) {
                          setState(() {
                            _isMultiSelectMode = false;
                          });
                          print(
                              '🔄 Multi-select mode disabled - no messages selected');
                        }
                      } else {
                        // For other user's messages, just show options
                        _showMessageOptions(message);
                      }
                    } else {
                      // Only show message options when NOT in multi-select mode
                      // Clear selection if tapping on selected message
                      if (_selectedMessageForDeletion?.id == message.id) {
                        print('🔍 Clearing selected message');
                        _clearSelectedMessage();
                      } else {
                        print('🔍 Showing message options');
                        _showMessageOptions(message);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isMultiSelectMode &&
                              _selectedMessageIds.contains(message.id)
                          ? Colors.blue.withOpacity(0.1)
                          : _selectedMessageForDeletion?.id == message.id
                              ? Colors.red.withOpacity(0.1)
                              : isSearchResult
                                  ? (isMe
                                      ? AppTheme.primaryColor.withOpacity(0.8)
                                      : Colors.yellow[100])
                                  : (isMe
                                      ? AppTheme.primaryColor
                                      : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(20).copyWith(
                        topLeft: Radius.circular(isMe ? 20 : 4),
                        topRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      border: _isMultiSelectMode &&
                              _selectedMessageIds.contains(message.id)
                          ? Border.all(color: Colors.blue, width: 2)
                          : _selectedMessageForDeletion?.id == message.id
                              ? Border.all(color: Colors.red, width: 2)
                              : isSearchResult
                                  ? Border.all(color: Colors.orange, width: 2)
                                  : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle different message types
                        if (message.messageType == MessageType.image) ...[
                          _buildImageMessage(message, isMe),
                        ] else ...[
                          Text(
                            message.messageText,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isMe ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.getChatTime(),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isMe
                                    ? Colors.white.withOpacity(0.8)
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _buildMessageStatusIcon(message),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Show delete icon overlay when message is selected
                if (_selectedMessageForDeletion?.id == message.id)
                  Positioned(
                    top: 8,
                    right: isMe ? 8 : null,
                    left: isMe ? null : 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                // Show selection checkbox in multi-select mode
                if (_isMultiSelectMode && isMe)
                  Positioned(
                    top: 8,
                    right: isMe ? 8 : null,
                    left: isMe ? null : 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _selectedMessageIds.contains(message.id)
                            ? AppTheme.primaryColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedMessageIds.contains(message.id)
                              ? AppTheme.primaryColor
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _selectedMessageIds.contains(message.id)
                            ? Icons.check
                            : Icons.check_box_outline_blank,
                        color: _selectedMessageIds.contains(message.id)
                            ? Colors.white
                            : Colors.grey[600],
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Show reactions below message bubble (like WhatsApp)
          if (message.hasReactions()) ...[
            const SizedBox(height: 4),
            Container(
              margin: EdgeInsets.only(
                left: isMe ? 0 : 16,
                right: isMe ? 16 : 0,
              ),
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  _buildReactionsRow(message),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (!_isOtherUserTyping) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20).copyWith(
                topLeft: const Radius.circular(4),
                topRight: const Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated dots
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -4 * value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animation
        if (_isOtherUserTyping && mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Image picker button
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isUploadingImage ? null : _sendImageMessage,
                icon: _isUploadingImage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor),
                        ),
                      )
                    : const Icon(
                        Icons.image,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.poppins(
                    color: AppTheme.textSecondary,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                onChanged: _onTextChanged,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            backgroundImage: widget.otherUserAvatar != null
                ? NetworkImage(widget.otherUserAvatar!)
                : null,
            child: widget.otherUserAvatar == null
                ? Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName[0].toUpperCase()
                        : 'U',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Start conversation with ${widget.otherUserName}',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to begin chatting',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsRow(Message message) {
    final currentUserId = AuthService.getCurrentUserId();
    final userReaction = message.getUserReaction(currentUserId ?? '');

    // Group reactions by type and count
    final reactionCounts = <String, int>{};
    for (final reaction in message.reactions.values) {
      reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show reaction emojis with counts
        ...reactionCounts.entries.map((entry) {
          final reactionType = entry.key;
          final count = entry.value;
          final emoji = _getReactionEmoji(reactionType);
          final isUserReaction =
              message.reactions[currentUserId] == reactionType;

          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isUserReaction
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isUserReaction ? AppTheme.primaryColor : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 12),
                ),
                if (count > 1) ...[
                  const SizedBox(width: 2),
                  Text(
                    count.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isUserReaction
                          ? AppTheme.primaryColor
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  String _getReactionEmoji(String reactionType) {
    switch (reactionType.toLowerCase()) {
      case 'like':
        return '👍';
      case 'love':
        return '❤️';
      case 'laugh':
        return '😂';
      case 'wow':
        return '😮';
      case 'sad':
        return '😢';
      case 'angry':
        return '😠';
      default:
        return '👍';
    }
  }

  void _showReactionOptions(Message message) {
    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'React to message',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ReactionType.values.map((reaction) {
                final isSelected =
                    message.getUserReaction(currentUserId) == reaction.name;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction(message, reaction.name);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryColor)
                          : null,
                    ),
                    child: Text(
                      reaction.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (message.getUserReaction(currentUserId) != null) ...[
              const Divider(),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _removeReaction(message);
                },
                child: Text(
                  'Remove reaction',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addReaction(Message message, String reactionType) async {
    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return;

    try {
      // Save reaction to database
      await MessageService.addReaction(message.id, reactionType);

      // Update local message
      final updatedMessage = message.copyWith(
        reactions: {...message.reactions, currentUserId: reactionType},
      );

      // Update message in list
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        setState(() {
          _messages[index] = updatedMessage;
        });
      }
    } catch (e) {
      print('❌ Error adding reaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add reaction')),
      );
    }
  }

  void _removeReaction(Message message) async {
    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return;

    try {
      // Remove reaction from database
      await MessageService.removeReaction(message.id);

      // Update local message
      final updatedReactions = Map<String, String>.from(message.reactions);
      updatedReactions.remove(currentUserId);

      final updatedMessage = message.copyWith(reactions: updatedReactions);

      // Update message in list
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        setState(() {
          _messages[index] = updatedMessage;
        });
      }
    } catch (e) {
      print('❌ Error removing reaction: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove reaction')),
      );
    }
  }

  // Message search methods
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _filteredMessages = [];
        _currentSearchIndex = -1;
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;

      if (query.isEmpty) {
        _filteredMessages = [];
        _currentSearchIndex = -1;
      } else {
        _filteredMessages = _messages.where((message) {
          return message.messageText
              .toLowerCase()
              .contains(query.toLowerCase());
        }).toList();

        // Auto-scroll to first result if found
        if (_filteredMessages.isNotEmpty) {
          _scrollToMessage(_filteredMessages.first);
        }
      }
    });
  }

  void _scrollToMessage(Message message) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      _scrollController.animateTo(
        index * 80.0, // Approximate message height
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showMessageOptions(Message message) {
    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Message options',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _startReply(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                _startForward(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message);
              },
            ),
            if (message.isSentByUser(currentUserId)) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startReply(Message message) {
    setState(() {
      _replyingTo = message;
      _isForwarding = false;
      _forwardingMessage = null;
    });
    _messageFocusNode.requestFocus();
  }

  void _startForward(Message message) {
    setState(() {
      _forwardingMessage = message;
      _isForwarding = true;
      _replyingTo = null;
    });
    _messageFocusNode.requestFocus();
  }

  void _copyMessage(Message message) {
    // Copy message text to clipboard
    // In a real app, you would use Clipboard.setData()
    print('📋 Copied message: ${message.messageText}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  void _editMessage(Message message) {
    // For now, we'll just show a snackbar
    // In a real app, you would implement message editing
    print('✏️ Edit message: ${message.id}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message editing coming soon!')),
    );
  }

  void _deleteMessage(Message message) {
    // For now, we'll just show a snackbar
    // In a real app, you would implement message deletion
    print('🗑️ Delete message: ${message.id}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message deletion coming soon!')),
    );
  }

  void _cancelReplyOrForward() {
    setState(() {
      _replyingTo = null;
      _isForwarding = false;
      _forwardingMessage = null;
    });
  }

  // Helper method to get status color based on real status
  Color _getStatusColor() {
    if (_isStatusLoading) {
      return AppTheme.textSecondary; // Grey for loading
    }

    if (_currentStatus.contains('Active now')) {
      return AppTheme.successColor; // Green for online
    } else {
      return AppTheme.textSecondary; // Grey for offline
    }
  }

  // Helper method to get status text
  String _getStatusText() {
    if (_isStatusLoading) {
      return 'Loading...';
    }
    return _currentStatus;
  }

  // Set up real-time message subscription
  void _setupRealTimeSubscription() {
    print('🔴 Setting up real-time subscription for chat screen');
    _messageSubscription =
        MessageService.subscribeToMessages(widget.conversationId).listen(
            (messages) {
      print('🔴 Real-time update received: ${messages.length} messages');

      if (mounted) {
        setState(() {
          _messages = messages;
        });

        // Scroll to bottom if new message was added
        if (messages.length > _messages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    }, onError: (error) {
      print('❌ Real-time subscription error: $error');
      // Fallback: reload messages manually
      if (mounted) {
        _loadMessages();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _isMultiSelectMode ? Colors.blue.withOpacity(0.05) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor:
            _isMultiSelectMode ? Colors.blue.withOpacity(0.1) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            // Navigate to user's profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  userId: widget.otherUserId,
                ),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getAvatarColor(widget.otherUserName),
                backgroundImage:
                    null, // Always show background color for consistency
                child: widget.otherUserAvatar == null ||
                        widget.otherUserAvatar!.isEmpty
                    ? Text(
                        _getInitials(widget.otherUserName),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )
                    : ClipOval(
                        child: Image.network(
                          widget.otherUserAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              _getInitials(widget.otherUserName),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isMultiSelectMode
                                ? 'Select Messages (${_selectedMessageIds.length})'
                                : widget.otherUserName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _isMultiSelectMode
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isMultiSelectMode)
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                      ],
                    ),
                    if (!_isMultiSelectMode)
                      Text(
                        _getStatusText(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Show multi-select options when in multi-select mode
          if (_isMultiSelectMode) ...[
            Text(
              '${_selectedMessageIds.length}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.select_all,
                color: AppTheme.primaryColor,
              ),
              onPressed: _selectAllMessages,
            ),
            IconButton(
              icon: _isDeletingMessage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
              onPressed: _isDeletingMessage || _selectedMessageIds.isEmpty
                  ? null
                  : _deleteSelectedMessages,
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: AppTheme.textSecondary,
              ),
              onPressed: _clearAllSelections,
            ),
          ] else if (_selectedMessageForDeletion != null) ...[
            // Show delete option when single message is selected
            IconButton(
              icon: _isDeletingMessage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
              onPressed: _isDeletingMessage ? null : _deleteSelectedMessages,
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: AppTheme.textSecondary,
              ),
              onPressed: _clearSelectedMessage,
            ),
          ] else ...[
            // Normal app bar actions
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: AppTheme.primaryColor,
              ),
              onPressed: _toggleSearch,
            ),
            // Removed 3-dot button since multi-select is now automatic
          ],
        ],
      ),
      body: Column(
        children: [
          // Search bar
          if (_isSearching) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
          // Message options preview
          if (_replyingTo != null || _isForwarding) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    _replyingTo != null ? Icons.reply : Icons.forward,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingTo != null ? 'Replying to' : 'Forwarding',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          _replyingTo?.messageText ??
                              _forwardingMessage?.messageText ??
                              '',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _cancelReplyOrForward,
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount:
                            _messages.length + (_isOtherUserTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isOtherUserTyping) {
                            return _buildTypingIndicator();
                          }
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
          ),
          _buildTypingIndicator(), // Add typing indicator here
          _buildMessageInput(),
        ],
      ),
    );
  }
}
