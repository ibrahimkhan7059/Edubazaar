import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/conversation.dart';
import '../models/message.dart';
import 'auth_service.dart';
import 'network_service.dart';

class MessageService {
  static final _supabase = Supabase.instance.client;

  // Stream controllers for real-time updates
  static final Map<String, StreamController<List<Message>>>
      _messageStreamControllers = {};
  static final StreamController<List<Conversation>>
      _conversationStreamController =
      StreamController<List<Conversation>>.broadcast();

  // Cache for conversations
  static List<Conversation> _cachedConversations = [];

  // ============================================
  // CONVERSATION OPERATIONS
  // ============================================

  /// Get or create a conversation between two users
  static Future<String> getOrCreateConversation({
    required String otherUserId,
    String? listingId,
  }) async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User must be logged in to start conversations');
      }

      print(
          '🔍 Getting or creating conversation between $currentUserId and $otherUserId');

      // Call the database function to get or create conversation
      final response =
          await _supabase.rpc('get_or_create_conversation', params: {
        'user1_id': currentUserId,
        'user2_id': otherUserId,
        'listing_ref_id': listingId,
      });

      final conversationId = response as String;
      print('✅ Conversation ID: $conversationId');

      return conversationId;
    } catch (e) {
      print('❌ Error getting/creating conversation: $e');
      throw Exception('Failed to start conversation: ${e.toString()}');
    }
  }

  /// Get or create a conversation with user info (name, avatar)
  static Future<Map<String, dynamic>> getOrCreateConversationWithUserInfo({
    required String otherUserId,
    String? listingId,
  }) async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User must be logged in to start conversations');
      }

      print('🔍 Getting conversation and user info for: $otherUserId');

      // Get user profile information first
      final userProfile = await _supabase
          .from('user_profiles')
          .select('id, name, profile_pic_url')
          .eq('id', otherUserId)
          .single();

      print('👤 Found user: ${userProfile['name']}');

      // Get or create conversation
      final conversationId = await getOrCreateConversation(
        otherUserId: otherUserId,
        listingId: listingId,
      );

      return {
        'conversationId': conversationId,
        'otherUserName': userProfile['name'] ?? 'User',
        'otherUserAvatar': userProfile['profile_pic_url'],
        'otherUserId': otherUserId,
      };
    } catch (e) {
      print('❌ Error getting conversation with user info: $e');
      throw Exception('Failed to get user information: ${e.toString()}');
    }
  }

  /// Get all conversations for current user
  static Future<List<Conversation>> getConversations() async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        print('❌ No user logged in');
        return [];
      }

      print('📱 Loading conversations for user: $currentUserId');

      // Use only the basic conversations table for now
      List<Map<String, dynamic>> response;

      try {
        print('🔍 Querying conversations table directly...');

        // Simple query to get conversations without joins
        print('🔍 Executing conversations query...');
        response = await _supabase
            .from('conversations')
            .select('*')
            .or('participant_1_id.eq.$currentUserId,participant_2_id.eq.$currentUserId')
            .order('last_message_at', ascending: false);

        print('📊 Query completed, response length: ${response.length}');

        if (response.isNotEmpty) {
          print('📋 First conversation data: ${response.first}');
          print('🔍 Checking participant IDs:');
          print('   P1: ${response.first['participant_1_id']}');
          print('   P2: ${response.first['participant_2_id']}');
          print('   Current user: $currentUserId');
          print(
              '   Matches P1: ${response.first['participant_1_id'] == currentUserId}');
          print(
              '   Matches P2: ${response.first['participant_2_id'] == currentUserId}');
        }
      } catch (queryError) {
        print('❌ Error querying conversations table: $queryError');
        print('❌ Error type: ${queryError.runtimeType}');

        // Return empty list on query error
        _cachedConversations = [];
        if (!_conversationStreamController.isClosed) {
          _conversationStreamController.add([]);
        }
        return [];
      }

      if (response.isEmpty) {
        print('ℹ️ No conversations found for user');
        _cachedConversations = [];
        _conversationStreamController.add([]);
        return [];
      }

      final conversations = <Conversation>[];

      for (final json in response) {
        try {
          print('🔄 Processing conversation: ${json['id']}');

          // Handle potential null values in conversation data
          final processedJson = await _processConversationJson(json);
          final conversation = Conversation.fromJson(processedJson);
          conversations.add(conversation);

          print('✅ Processed conversation: ${conversation.id}');
        } catch (convError) {
          print('⚠️ Error processing conversation: $convError');
          print('🔍 Raw data: $json');
          // Skip this conversation and continue with others
          continue;
        }
      }

      print('✅ Loaded ${conversations.length} conversations successfully');

      // Fetch user profiles for participants
      print('🔄 Fetching user profiles for participants...');
      await _fetchUserProfilesForConversations(conversations);

      // Update cache
      _cachedConversations = conversations;

      // Notify listeners
      if (!_conversationStreamController.isClosed) {
        _conversationStreamController.add(conversations);
      }

      return conversations;
    } catch (e) {
      print('❌ Error loading conversations: $e');
      print('❌ Error type: ${e.runtimeType}');

      // Check if it's a network error
      if (NetworkService.isNetworkError(e)) {
        print('🌐 Network connectivity issue detected');

        // Get detailed network status
        final networkStatus = await NetworkService.getDetailedNetworkStatus();
        print('💡 Network Status: $networkStatus');

        // Try to retry the operation with exponential backoff
        try {
          print('🔄 Attempting to retry conversation loading...');
          final conversations = await NetworkService.retryOperation(
            operation: () => getConversations(),
            maxRetries: 2,
            initialDelay: const Duration(seconds: 1),
          );

          // Update cache
          _cachedConversations = conversations;
          if (!_conversationStreamController.isClosed) {
            _conversationStreamController.add(conversations);
          }
          return conversations;
        } catch (retryError) {
          print('❌ Retry failed: $retryError');
        }
      }

      // Return empty list instead of throwing exception for better UX
      _cachedConversations = [];
      if (!_conversationStreamController.isClosed) {
        _conversationStreamController.add([]);
      }
      return [];
    }
  }

  /// Process conversation JSON to handle null values and missing fields
  static Future<Map<String, dynamic>> _processConversationJson(
      Map<String, dynamic> json) async {
    // Ensure all required fields have default values
    final processedJson = Map<String, dynamic>.from(json);

    // Basic conversation fields
    processedJson['id'] = json['id'] ?? '';
    processedJson['participant_1_id'] = json['participant_1_id'] ?? '';
    processedJson['participant_2_id'] = json['participant_2_id'] ?? '';
    processedJson['listing_id'] = json['listing_id'];
    processedJson['last_message_id'] = json['last_message_id'];

    // Handle last_message_at with better error handling
    try {
      if (json['last_message_at'] != null) {
        processedJson['last_message_at'] = json['last_message_at'];
      } else {
        processedJson['last_message_at'] = DateTime.now().toIso8601String();
      }
    } catch (e) {
      print('⚠️ Error processing last_message_at: $e');
      processedJson['last_message_at'] = DateTime.now().toIso8601String();
    }

    processedJson['participant_1_unread_count'] =
        json['participant_1_unread_count'] ?? 0;
    processedJson['participant_2_unread_count'] =
        json['participant_2_unread_count'] ?? 0;
    processedJson['is_active'] = json['is_active'] ?? true;

    // Handle created_at with better error handling
    try {
      if (json['created_at'] != null) {
        processedJson['created_at'] = json['created_at'];
      } else {
        processedJson['created_at'] = DateTime.now().toIso8601String();
      }
    } catch (e) {
      print('⚠️ Error processing created_at: $e');
      processedJson['created_at'] = DateTime.now().toIso8601String();
    }

    // Handle updated_at with better error handling
    try {
      if (json['updated_at'] != null) {
        processedJson['updated_at'] = json['updated_at'];
      } else {
        processedJson['updated_at'] = DateTime.now().toIso8601String();
      }
    } catch (e) {
      print('⚠️ Error processing updated_at: $e');
      processedJson['updated_at'] = DateTime.now().toIso8601String();
    }

    // Set default values for participant details (will be fetched separately)
    processedJson['participant_1_name'] = 'User 1';
    processedJson['participant_1_avatar'] = null;
    processedJson['participant_2_name'] = 'User 2';
    processedJson['participant_2_avatar'] = null;

    // Fetch actual last message from messages table
    try {
      final conversationId = json['id'];
      final lastMessageResponse = await _supabase
          .from('messages')
          .select('message_text, message_type, sender_id')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(1);

      if (lastMessageResponse.isNotEmpty) {
        final lastMessage = lastMessageResponse.first;
        processedJson['last_message_text'] =
            lastMessage['message_text'] ?? 'No messages yet';
        processedJson['last_message_type'] =
            lastMessage['message_type'] ?? 'text';
        processedJson['last_message_sender_id'] = lastMessage['sender_id'];
        print('✅ Fetched last message: ${lastMessage['message_text']}');
      } else {
        processedJson['last_message_text'] = 'No messages yet';
        processedJson['last_message_type'] = 'text';
        processedJson['last_message_sender_id'] = null;
        print('ℹ️ No messages found for conversation: $conversationId');
      }
    } catch (e) {
      print('❌ Error fetching last message: $e');
      processedJson['last_message_text'] = 'No messages yet';
      processedJson['last_message_type'] = 'text';
      processedJson['last_message_sender_id'] = null;
    }

    // Listing details
    processedJson['listing_title'] = json['listing_title'];
    processedJson['listing_images'] = json['listing_images'];

    print('🔍 Processed JSON keys: ${processedJson.keys.toList()}');
    print('🔍 last_message_text: ${processedJson['last_message_text']}');

    return processedJson;
  }

  /// Mark message as delivered
  static Future<void> _markMessageAsDelivered(String messageId) async {
    try {
      await Future.delayed(
          const Duration(seconds: 1)); // Simulate network delay
      await _supabase.from('messages').update({
        'is_delivered': true,
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);
      print('✅ Message marked as delivered: $messageId');
    } catch (e) {
      print('❌ Error marking message as delivered: $e');
    }
  }

  /// Mark message as read
  static Future<void> markMessageAsRead(String messageId) async {
    try {
      await _supabase.from('messages').update({
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);
      print('✅ Message marked as read: $messageId');
    } catch (e) {
      print('❌ Error marking message as read: $e');
    }
  }

  /// Mark conversation as read for current user
  static Future<void> markConversationAsRead(String conversationId) async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) return;

      print('📖 Marking conversation as read: $conversationId');

      // Try using RPC function first
      try {
        await _supabase.rpc('mark_messages_as_read', params: {
          'conv_id': conversationId,
          'user_id': currentUserId,
        });
      } catch (rpcError) {
        print('⚠️ RPC function not available, using direct update');
        // Fallback: Update messages directly
        await _supabase
            .from('messages')
            .update({
              'is_read': true,
              'read_at': DateTime.now().toIso8601String(),
            })
            .eq('conversation_id', conversationId)
            .neq('sender_id', currentUserId); // Don't mark own messages as read
      }

      print('✅ Conversation marked as read');

      // Refresh conversations to update unread counts
      getConversations();
    } catch (e) {
      print('❌ Error marking conversation as read: $e');
    }
  }

  /// Get total unread messages count for current user
  static Future<int> getTotalUnreadCount() async {
    try {
      final conversations = _cachedConversations.isNotEmpty
          ? _cachedConversations
          : await getConversations();

      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) return 0;

      int totalUnread = 0;
      for (final conv in conversations) {
        totalUnread += conv.getUnreadCount(currentUserId);
      }

      return totalUnread;
    } catch (e) {
      print('❌ Error getting total unread count: $e');
      return 0;
    }
  }

  // ============================================
  // MESSAGE OPERATIONS
  // ============================================

  /// Send a new message
  static Future<Message> sendMessage({
    required String conversationId,
    required String messageText,
    MessageType messageType = MessageType.text,
    String? attachmentUrl,
    String? listingReferenceId,
  }) async {
    try {
      // Validate inputs
      if (conversationId.isEmpty) {
        throw Exception('Conversation ID cannot be empty');
      }

      // Allow empty text for image messages
      if (messageText.isEmpty && messageType != MessageType.image) {
        throw Exception('Message text cannot be empty');
      }

      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User must be logged in to send messages');
      }

      print('📤 Sending message to conversation: $conversationId');
      print('📝 Message text: $messageText');
      print('👤 Current user: $currentUserId');

      // Check if conversation exists
      final exists = await conversationExists(conversationId);
      if (!exists) {
        throw Exception('Conversation not found. Please try again.');
      }

      // Get conversation details to identify recipient
      final conversation = await _supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .single();

      print('🔍 Found conversation: ${conversation['id']}');
      print(
          '👥 Participants: ${conversation['participant_1_id']} and ${conversation['participant_2_id']}');

      final String recipientId =
          conversation['participant_1_id'] == currentUserId
              ? conversation['participant_2_id']
              : conversation['participant_1_id'];

      print('📨 Recipient ID: $recipientId');

      // Create message data
      final messageData = {
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'message_text': messageText,
        'message_type': messageType.name,
        'attachment_url': attachmentUrl,
        'listing_reference_id': listingReferenceId,
        'is_read': false,
      };

      // Insert message into database
      print('💾 Inserting message data: $messageData');

      final response = await _supabase
          .from('messages')
          .insert(messageData)
          .select()
          .single();

      print('📄 Database response: $response');

      final message = Message.fromJson(response);
      print('✅ Message sent successfully: ${message.id}');

      // Don't automatically mark as delivered - let it show as sent
      // In a real app, this would be done when other user comes online
      // _markMessageAsDelivered(message.id);

      return message;
    } catch (e) {
      print('❌ Error sending message: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error details: ${e.toString()}');

      // Provide more specific error messages
      if (e.toString().contains('conversation')) {
        throw Exception('Conversation not found. Please try again.');
      } else if (e.toString().contains('null')) {
        throw Exception(
            'Invalid data. Please check your message and try again.');
      } else {
        throw Exception('Failed to send message: ${e.toString()}');
      }
    }
  }

  /// Get messages for a conversation with pagination
  static Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      print('📥 Loading messages for conversation: $conversationId');

      // Load messages without join (to avoid foreign key issues)
      final response = await _supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('📄 Raw messages response: ${response.length} messages');

      final messages = <Message>[];

      // Collect all unique sender IDs
      final Set<String> senderIds = {};
      for (final json in response) {
        senderIds.add(json['sender_id']);
      }

      // Fetch all sender profiles in one query
      Map<String, Map<String, dynamic>> senderProfiles = {};
      if (senderIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('user_profiles')
              .select('id, name, profile_pic_url')
              .inFilter('id', senderIds.toList());

          for (final profile in profiles) {
            senderProfiles[profile['id']] = profile;
          }
          print('👥 Fetched ${profiles.length} sender profiles');
        } catch (profileError) {
          print('⚠️ Could not fetch sender profiles: $profileError');
        }
      }

      // Process messages with sender info
      for (final json in response) {
        final senderId = json['sender_id'];
        final senderProfile = senderProfiles[senderId];

        if (senderProfile != null) {
          json['sender_name'] = senderProfile['name'] ?? 'Unknown User';
          json['sender_avatar'] = senderProfile['profile_pic_url'];
        } else {
          json['sender_name'] = 'Unknown User';
          json['sender_avatar'] = null;
        }

        messages.add(Message.fromJson(json));
      }

      // Reverse to show oldest first (chat order)
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      print('✅ Loaded ${messages.length} messages successfully');
      return messages;
    } catch (e) {
      print('❌ Error loading messages: $e');
      print('❌ Error type: ${e.runtimeType}');
      throw Exception('Failed to load messages: ${e.toString()}');
    }
  }

  /// Send a text message (convenience method)
  static Future<Message> sendTextMessage(String conversationId, String text) {
    return sendMessage(
      conversationId: conversationId,
      messageText: text,
      messageType: MessageType.text,
    );
  }

  /// Send an image message (convenience method)
  static Future<Message> sendImageMessage(
    String conversationId,
    String imageUrl, {
    String caption = '',
  }) {
    return sendMessage(
      conversationId: conversationId,
      messageText: caption,
      messageType: MessageType.image,
      attachmentUrl: imageUrl,
    );
  }

  /// Delete a message
  static Future<void> deleteMessage(String messageId) async {
    try {
      print('🗑️ Deleting message: $messageId');

      // Check if user owns the message
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('User must be logged in to delete messages');
      }

      // Get message to check ownership and get attachment info
      final messageResponse = await _supabase
          .from('messages')
          .select('sender_id, attachment_url, conversation_id')
          .eq('id', messageId)
          .single();

      if (messageResponse['sender_id'] != currentUserId) {
        throw Exception('You can only delete your own messages');
      }

      final attachmentUrl = messageResponse['attachment_url'];
      final conversationId = messageResponse['conversation_id'];

      // Delete from database first
      await _supabase.from('messages').delete().eq('id', messageId);
      print('✅ Message deleted from database');

      // Verify deletion by trying to fetch the message
      try {
        final verifyResponse = await _supabase
            .from('messages')
            .select('id')
            .eq('id', messageId)
            .maybeSingle();

        if (verifyResponse != null) {
          print('⚠️ WARNING: Message still exists after deletion!');
          throw Exception(
              'Message deletion failed - message still exists in database');
        } else {
          print('✅ Message deletion verified - message no longer exists');
        }
      } catch (e) {
        if (e.toString().contains('Message deletion failed')) {
          throw e; // Re-throw our custom error
        }
        print('✅ Message deletion verified (error expected): $e');
      }

      // If message has attachment, delete from storage
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
        try {
          print('🗑️ Processing attachment deletion for URL: $attachmentUrl');

          // Extract file path from URL
          final uri = Uri.parse(attachmentUrl);
          final pathSegments = uri.pathSegments;
          print('🔍 URL path segments: $pathSegments');

          // Find the file path after 'chat-attachments'
          final bucketIndex = pathSegments.indexOf('chat-attachments');
          print('🔍 Bucket index: $bucketIndex');

          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
            print('🗑️ Deleting attachment from storage: $filePath');

            // List files before deletion for debugging
            try {
              final files =
                  await _supabase.storage.from('chat-attachments').list();
              print('📁 Files in bucket before deletion: ${files.length}');
              for (final file in files) {
                print('  - ${file.name}');
              }
            } catch (e) {
              print('⚠️ Could not list files: $e');
            }

            await _supabase.storage.from('chat-attachments').remove([filePath]);
            print('✅ Attachment deleted from storage');

            // List files after deletion for debugging
            try {
              final filesAfter =
                  await _supabase.storage.from('chat-attachments').list();
              print('📁 Files in bucket after deletion: ${filesAfter.length}');
            } catch (e) {
              print('⚠️ Could not list files after deletion: $e');
            }
          } else {
            print('⚠️ Could not extract file path from URL: $attachmentUrl');
            print('⚠️ Path segments: $pathSegments');
            print('⚠️ Bucket index: $bucketIndex');
          }
        } catch (e) {
          print('⚠️ Could not delete attachment from storage: $e');
          print('⚠️ Error type: ${e.runtimeType}');
          // Don't throw error - message was deleted successfully
        }
      } else {
        print('ℹ️ No attachment to delete');
      }

      // Force refresh the message stream for this conversation
      if (conversationId != null) {
        // Clear cache first, then refresh
        clearMessageStreamCache(conversationId);
        await Future.delayed(const Duration(milliseconds: 200));
        _refreshMessageStream(conversationId);
      }

      print('✅ Message and attachment deleted successfully');
    } catch (e) {
      print('❌ Error deleting message: $e');
      throw Exception('Failed to delete message: ${e.toString()}');
    }
  }

  /// Force refresh message stream for a conversation
  static void _refreshMessageStream(String conversationId) {
    print('🔄 Refreshing message stream for conversation: $conversationId');

    // Get fresh messages from database
    getMessages(conversationId).then((messages) {
      if (_messageStreamControllers.containsKey(conversationId)) {
        _messageStreamControllers[conversationId]!.add(messages);
        print('✅ Message stream refreshed');
      }
    }).catchError((e) {
      print('❌ Error refreshing message stream: $e');
    });
  }

  /// Manually refresh messages for a conversation (public method)
  static Future<void> refreshMessages(String conversationId) async {
    print('🔄 Manually refreshing messages for conversation: $conversationId');

    try {
      // Clear any cached data first
      if (_messageStreamControllers.containsKey(conversationId)) {
        // Clear the stream controller to ensure fresh data
        _messageStreamControllers[conversationId]!.close();
        _messageStreamControllers[conversationId] =
            StreamController<List<Message>>.broadcast();
      }

      final messages = await getMessages(conversationId);
      print('📥 Fresh messages loaded: ${messages.length}');

      if (_messageStreamControllers.containsKey(conversationId)) {
        _messageStreamControllers[conversationId]!.add(messages);
        print('✅ Messages manually refreshed: ${messages.length} messages');
      }
    } catch (e) {
      print('❌ Error manually refreshing messages: $e');
    }
  }

  /// Clear message stream cache for a conversation
  static void clearMessageStreamCache(String conversationId) {
    print(
        '🗑️ Clearing message stream cache for conversation: $conversationId');

    if (_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId]!.close();
      _messageStreamControllers.remove(conversationId);
      print('✅ Message stream cache cleared');
    }
  }

  /// Share a listing in conversation (convenience method)
  static Future<Message> shareListingMessage(
    String conversationId,
    String listingId, {
    String? customMessage,
  }) {
    return sendMessage(
      conversationId: conversationId,
      messageText: customMessage ?? 'Shared a listing',
      messageType: MessageType.listingShare,
      listingReferenceId: listingId,
    );
  }

  // ============================================
  // REAL-TIME MESSAGING
  // ============================================

  /// Subscribe to real-time messages for a conversation
  static Stream<List<Message>> subscribeToMessages(String conversationId) {
    // Create stream controller if not exists
    if (!_messageStreamControllers.containsKey(conversationId)) {
      _messageStreamControllers[conversationId] =
          StreamController<List<Message>>.broadcast();

      // Set up real-time subscription
      _setupMessageSubscription(conversationId);
    }

    return _messageStreamControllers[conversationId]!.stream;
  }

  /// Set up real-time subscription for messages
  static void _setupMessageSubscription(String conversationId) {
    print(
        '🔴 Setting up real-time subscription for conversation: $conversationId');

    // Use a different approach - listen to all changes and manually refresh
    _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .listen((data) async {
          print(
              '🔴 Real-time message update received: ${data.length} messages');

          // Add a small delay to avoid race conditions
          await Future.delayed(const Duration(milliseconds: 100));

          // Always get fresh data from database to ensure consistency
          try {
            final freshMessages = await getMessages(conversationId);
            print('🔄 Fresh messages count: ${freshMessages.length}');

            // Notify listeners with fresh data
            if (_messageStreamControllers.containsKey(conversationId)) {
              _messageStreamControllers[conversationId]!.add(freshMessages);
              print(
                  '✅ Updated message stream with ${freshMessages.length} messages');
            }
          } catch (e) {
            print('❌ Error refreshing messages: $e');
          }
        }, onError: (error) {
          print('❌ Real-time subscription error: $error');
        });
  }

  /// Subscribe to real-time conversation updates
  static Stream<List<Conversation>> subscribeToConversations() {
    // Set up real-time subscription if not already done
    _setupConversationSubscription();

    return _conversationStreamController.stream;
  }

  /// Set up real-time subscription for conversations
  static void _setupConversationSubscription() {
    final currentUserId = AuthService.getCurrentUserId();
    if (currentUserId == null) return;

    print('🔴 Setting up real-time subscription for conversations');

    // Subscribe to conversations where user is a participant
    // We'll listen to both participant columns separately due to stream limitations
    _supabase.from('conversations').stream(primaryKey: ['id']).listen((data) {
      print('🔴 Real-time conversation update received');

      // Filter conversations for current user and refresh
      final userConversations = data.where((conv) {
        return conv['participant_1_id'] == currentUserId ||
            conv['participant_2_id'] == currentUserId;
      }).toList();

      if (userConversations.isNotEmpty) {
        // Refresh conversations from detailed view
        getConversations();
      }
    });
  }

  // ============================================
  // TYPING INDICATORS
  // ============================================

  /// Send typing indicator
  static Future<void> sendTypingIndicator(
      String conversationId, bool isTyping) async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) return;

      if (isTyping) {
        // Send typing started
        await _supabase.from('typing_indicators').upsert({
          'conversation_id': conversationId,
          'user_id': currentUserId,
          'is_typing': true,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'conversation_id,user_id', ignoreDuplicates: false);
      } else {
        // Remove typing indicator
        await _supabase
            .from('typing_indicators')
            .delete()
            .eq('conversation_id', conversationId)
            .eq('user_id', currentUserId);
      }
    } catch (e) {
      print('❌ Error sending typing indicator: $e');
    }
  }

  /// Listen to typing indicators
  static void listenToTypingIndicators(
    String conversationId,
    String otherUserId,
    Function(bool) onTypingChanged,
  ) {
    try {
      // For now, we'll simulate typing indicators
      // In a real app, you would use Supabase Realtime

      // Simulate typing indicator for demo
      Timer.periodic(const Duration(seconds: 10), (timer) {
        // Randomly show typing indicator for demo
        if (DateTime.now().millisecondsSinceEpoch % 30 == 0) {
          onTypingChanged(true);

          // Hide after 3 seconds
          Timer(const Duration(seconds: 3), () {
            onTypingChanged(false);
          });
        }
      });
    } catch (e) {
      print('❌ Error listening to typing indicators: $e');
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Check if user has any unread messages
  static Future<bool> hasUnreadMessages() async {
    final unreadCount = await getTotalUnreadCount();
    return unreadCount > 0;
  }

  /// Search conversations by participant name
  static List<Conversation> searchConversations(String query) {
    if (query.isEmpty) return _cachedConversations;

    return _cachedConversations.where((conv) {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) return false;

      final otherParticipantName =
          conv.getOtherParticipantName(currentUserId)?.toLowerCase() ?? '';
      return otherParticipantName.contains(query.toLowerCase());
    }).toList();
  }

  /// Get conversation by ID from cache
  static Conversation? getCachedConversation(String conversationId) {
    try {
      return _cachedConversations
          .firstWhere((conv) => conv.id == conversationId);
    } catch (e) {
      return null;
    }
  }

  /// Clean up resources
  static void dispose() {
    print('🧹 Cleaning up MessageService resources');

    // Close all stream controllers
    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
    _messageStreamControllers.clear();

    if (!_conversationStreamController.isClosed) {
      _conversationStreamController.close();
    }

    // Clear cache
    _cachedConversations.clear();
  }

  // ============================================
  // ADMIN/DEBUG METHODS
  // ============================================

  /// Get message statistics (for debugging)
  static Future<Map<String, int>> getMessageStats() async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) return {};

      // Get total conversations
      final conversations = await getConversations();

      // Get total messages sent by user
      final sentMessages = await _supabase
          .from('messages')
          .select('id')
          .eq('sender_id', currentUserId);

      // Get total unread messages
      final unreadCount = await getTotalUnreadCount();

      return {
        'total_conversations': conversations.length,
        'total_messages_sent': sentMessages.length,
        'total_unread': unreadCount,
      };
    } catch (e) {
      print('❌ Error getting message stats: $e');
      return {};
    }
  }

  /// Delete conversation (admin only - if needed)
  static Future<void> deleteConversation(String conversationId) async {
    try {
      await _supabase.from('conversations').delete().eq('id', conversationId);

      print('✅ Conversation deleted: $conversationId');

      // Refresh conversations
      getConversations();
    } catch (e) {
      print('❌ Error deleting conversation: $e');
      throw Exception('Failed to delete conversation: ${e.toString()}');
    }
  }

  /// Create a test conversation for demo purposes
  static Future<void> createTestConversation() async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        print('❌ No user logged in for test conversation');
        return;
      }

      print('🧪 Creating test conversation...');

      // Check if any conversations exist
      final existingConversations = await _supabase
          .from('conversations')
          .select('*')
          .or('participant_1_id.eq.$currentUserId,participant_2_id.eq.$currentUserId');

      if (existingConversations.isNotEmpty) {
        print('ℹ️ Conversations already exist, skipping test creation');
        return;
      }

      // Create a test conversation with a dummy user
      final testConversation = await _supabase
          .from('conversations')
          .insert({
            'participant_1_id': currentUserId,
            'participant_2_id':
                '00000000-0000-0000-0000-000000000001', // Dummy user ID
            'last_message_at': DateTime.now().toIso8601String(),
            'participant_1_unread_count': 0,
            'participant_2_unread_count': 0,
            'is_active': true,
          })
          .select()
          .single();

      print('✅ Test conversation created: ${testConversation['id']}');

      // Create a test message
      await _supabase.from('messages').insert({
        'conversation_id': testConversation['id'],
        'sender_id': '00000000-0000-0000-0000-000000000001', // Dummy user
        'message_text': 'Hello! Welcome to EduBazaar messaging! 👋',
        'message_type': 'text',
        'is_read': false,
      });

      print('✅ Test message created');
    } catch (e) {
      print('❌ Error creating test conversation: $e');
    }
  }

  /// Create a test message in an existing conversation
  static Future<void> createTestMessage(String conversationId) async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        print('❌ No user logged in for test message');
        return;
      }

      print('🧪 Creating test message in conversation: $conversationId');

      // Create a test message
      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'message_text':
            'Hello! This is a test message from ${DateTime.now().toString()}',
        'message_type': 'text',
        'is_read': false,
      });

      print('✅ Test message created successfully');
    } catch (e) {
      print('❌ Error creating test message: $e');
    }
  }

  /// Check if conversations table exists and is accessible
  static Future<bool> checkConversationsTable() async {
    try {
      print('🔍 Checking if conversations table exists...');

      // Try a simple query to check if table exists
      await _supabase.from('conversations').select('id').limit(1);

      print('✅ Conversations table is accessible');
      return true;
    } catch (e) {
      print('❌ Conversations table check failed: $e');
      print('❌ Error type: ${e.runtimeType}');
      return false;
    }
  }

  /// Check if a conversation exists
  static Future<bool> conversationExists(String conversationId) async {
    try {
      final response = await _supabase
          .from('conversations')
          .select('id')
          .eq('id', conversationId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      print('❌ Error checking conversation existence: $e');
      return false;
    }
  }

  /// Fetch user profiles for conversations
  static Future<void> _fetchUserProfilesForConversations(
      List<Conversation> conversations) async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) return;

      // Collect all unique user IDs from conversations
      final Set<String> userIds = {};
      for (final conversation in conversations) {
        userIds.add(conversation.participant1Id);
        userIds.add(conversation.participant2Id);
      }

      if (userIds.isEmpty) return;

      print('👥 Fetching profiles for ${userIds.length} users');

      // Fetch all user profiles in one query
      final userProfiles = await _supabase
          .from('user_profiles')
          .select('id, name, profile_pic_url')
          .inFilter('id', userIds.toList());

      // Create a map for quick lookup
      final Map<String, Map<String, dynamic>> userMap = {};
      for (final profile in userProfiles) {
        userMap[profile['id']] = profile;
      }

      print('✅ Fetched ${userProfiles.length} user profiles');

      // Create new conversation objects with user data
      final updatedConversations = <Conversation>[];
      for (final conversation in conversations) {
        final p1Profile = userMap[conversation.participant1Id];
        final p2Profile = userMap[conversation.participant2Id];

        final updatedConversation = conversation.copyWith(
          participant1Name: p1Profile?['name'] ?? 'Unknown User',
          participant1Avatar: p1Profile?['profile_pic_url'],
          participant2Name: p2Profile?['name'] ?? 'Unknown User',
          participant2Avatar: p2Profile?['profile_pic_url'],
        );

        updatedConversations.add(updatedConversation);
      }

      // Replace the original list
      conversations.clear();
      conversations.addAll(updatedConversations);
    } catch (e) {
      print('❌ Error fetching user profiles: $e');
    }
  }

  /// Simple test to check if conversations table is accessible
  static Future<void> testConversationsTable() async {
    try {
      print('🧪 Testing conversations table access...');

      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        print('❌ No user logged in');
        return;
      }

      print('👤 Current user: $currentUserId');

      // Try to access conversations table
      final result = await _supabase
          .from('conversations')
          .select('id, participant_1_id, participant_2_id')
          .limit(5);

      print('✅ Conversations table accessible!');
      print('📊 Found ${result.length} conversations');

      if (result.isNotEmpty) {
        print('📋 Sample conversation: ${result.first}');
      }
    } catch (e) {
      print('❌ Conversations table test failed: $e');
      print('❌ Error type: ${e.runtimeType}');
    }
  }

  /// Debug method to test the exact query
  static Future<void> debugConversationQuery() async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        print('❌ No user logged in');
        return;
      }

      print('🔍 Debug: Testing conversation query for user: $currentUserId');

      // Test the exact query
      final response = await _supabase
          .from('conversations')
          .select('*')
          .or('participant_1_id.eq.$currentUserId,participant_2_id.eq.$currentUserId')
          .order('last_message_at', ascending: false);

      print('📊 Debug query result: ${response.length} conversations');

      for (int i = 0; i < response.length; i++) {
        final conv = response[i];
        print('📋 Conversation $i:');
        print('   ID: ${conv['id']}');
        print('   P1: ${conv['participant_1_id']}');
        print('   P2: ${conv['participant_2_id']}');
        print(
            '   Current user matches P1: ${conv['participant_1_id'] == currentUserId}');
        print(
            '   Current user matches P2: ${conv['participant_2_id'] == currentUserId}');
      }
    } catch (e) {
      print('❌ Debug query failed: $e');
    }
  }

  /// Manual test with exact user ID from logs
  static Future<void> manualTestWithExactUserId() async {
    try {
      const currentUserId = '41395f14-0a93-45cf-a8e4-4d24c9d255da';

      print('🔍 Manual test with exact user ID: $currentUserId');

      // Test the exact query
      final response = await _supabase
          .from('conversations')
          .select('*')
          .or('participant_1_id.eq.$currentUserId,participant_2_id.eq.$currentUserId')
          .order('last_message_at', ascending: false);

      print('📊 Manual test result: ${response.length} conversations');

      for (int i = 0; i < response.length; i++) {
        final conv = response[i];
        print('📋 Conversation $i:');
        print('   ID: ${conv['id']}');
        print('   P1: ${conv['participant_1_id']}');
        print('   P2: ${conv['participant_2_id']}');
        print(
            '   Current user matches P1: ${conv['participant_1_id'] == currentUserId}');
        print(
            '   Current user matches P2: ${conv['participant_2_id'] == currentUserId}');
      }
    } catch (e) {
      print('❌ Manual test failed: $e');
    }
  }

  /// Compare debug query with actual getConversations method
  static Future<void> compareQueryMethods() async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        print('❌ No user logged in');
        return;
      }

      print('🔍 Comparing query methods for user: $currentUserId');

      // Method 1: Debug query (working)
      final debugResponse = await _supabase
          .from('conversations')
          .select('*')
          .or('participant_1_id.eq.$currentUserId,participant_2_id.eq.$currentUserId')
          .order('last_message_at', ascending: false);

      print('📊 Debug query result: ${debugResponse.length} conversations');

      // Method 2: Actual getConversations method
      final actualConversations = await getConversations();

      print(
          '📊 Actual getConversations result: ${actualConversations.length} conversations');

      // Compare results
      if (debugResponse.length != actualConversations.length) {
        print('❌ Mismatch found!');
        print('   Debug query: ${debugResponse.length} conversations');
        print('   Actual method: ${actualConversations.length} conversations');
      } else {
        print('✅ Both methods return same number of conversations');
      }
    } catch (e) {
      print('❌ Compare test failed: $e');
    }
  }

  /// Simple bypass method to test if processing is the issue
  static Future<List<Conversation>> getConversationsSimple() async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) {
        print('❌ No user logged in');
        return [];
      }

      print('🧪 Simple method: Loading conversations for user: $currentUserId');

      // Simple query without processing
      final response = await _supabase
          .from('conversations')
          .select('*')
          .or('participant_1_id.eq.$currentUserId,participant_2_id.eq.$currentUserId')
          .order('last_message_at', ascending: false);

      print('📊 Simple method: Found ${response.length} conversations');

      if (response.isNotEmpty) {
        print('📋 Simple method: First conversation: ${response.first['id']}');
      }

      // Create simple conversation objects without complex processing
      final conversations = <Conversation>[];
      for (final json in response) {
        try {
          // Create conversation with minimal processing
          final conversation = Conversation(
            id: json['id'] as String,
            participant1Id: json['participant_1_id'] as String,
            participant2Id: json['participant_2_id'] as String,
            listingId: json['listing_id'] as String?,
            lastMessageId: json['last_message_id'] as String?,
            lastMessageAt:
                DateTime.now(), // Use current time instead of parsing
            participant1UnreadCount:
                json['participant_1_unread_count'] as int? ?? 0,
            participant2UnreadCount:
                json['participant_2_unread_count'] as int? ?? 0,
            isActive: json['is_active'] as bool? ?? true,
            createdAt: DateTime.now(), // Use current time instead of parsing
            updatedAt: DateTime.now(), // Use current time instead of parsing
            participant1Name: 'User 1',
            participant1Avatar: null,
            participant2Name: 'User 2',
            participant2Avatar: null,
          );

          conversations.add(conversation);
          print('✅ Simple method: Processed conversation: ${conversation.id}');
        } catch (e) {
          print('❌ Simple method: Error processing conversation: $e');
        }
      }

      print('✅ Simple method: Loaded ${conversations.length} conversations');
      return conversations;
    } catch (e) {
      print('❌ Simple method failed: $e');
      return [];
    }
  }

  // ============================================
  // MESSAGE REACTIONS
  // ============================================

  /// Add reaction to a message
  static Future<void> addReaction(String messageId, String reactionType) async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) return;

      // Get current reactions
      final message = await _supabase
          .from('messages')
          .select('reactions')
          .eq('id', messageId)
          .single();

      Map<String, dynamic> reactions = {};
      if (message['reactions'] != null) {
        reactions = Map<String, dynamic>.from(message['reactions']);
      }

      // Add or update reaction
      reactions[currentUserId] = reactionType;

      // Update message with new reactions
      await _supabase
          .from('messages')
          .update({'reactions': reactions}).eq('id', messageId);

      print('👍 Reaction added: $reactionType to message: $messageId');
    } catch (e) {
      print('❌ Error adding reaction: $e');
    }
  }

  /// Remove reaction from a message
  static Future<void> removeReaction(String messageId) async {
    try {
      final currentUserId = AuthService.getCurrentUserId();
      if (currentUserId == null) return;

      // Get current reactions
      final message = await _supabase
          .from('messages')
          .select('reactions')
          .eq('id', messageId)
          .single();

      Map<String, dynamic> reactions = {};
      if (message['reactions'] != null) {
        reactions = Map<String, dynamic>.from(message['reactions']);
      }

      // Remove user's reaction
      reactions.remove(currentUserId);

      // Update message with updated reactions
      await _supabase
          .from('messages')
          .update({'reactions': reactions}).eq('id', messageId);

      print('❌ Reaction removed from message: $messageId');
    } catch (e) {
      print('❌ Error removing reaction: $e');
    }
  }

  /// Test method to verify storage deletion (for debugging)
  static Future<void> testStorageDeletion() async {
    try {
      print('🧪 Testing storage deletion...');

      // List all files in chat-attachments bucket
      final files = await _supabase.storage.from('chat-attachments').list();
      print('📁 Total files in bucket: ${files.length}');

      for (final file in files) {
        print(
            '  - ${file.name} (${file.metadata?['size'] ?? 'unknown'} bytes)');
      }

      print('✅ Storage test completed');
    } catch (e) {
      print('❌ Storage test failed: $e');
    }
  }

  /// Test method to verify message deletion (for debugging)
  static Future<void> testMessageDeletion(String conversationId) async {
    try {
      print('🧪 Testing message deletion for conversation: $conversationId');

      // Get current message count
      final messages = await getMessages(conversationId);
      print('📄 Current message count: ${messages.length}');

      // List all messages
      for (final message in messages) {
        print(
            '  - ${message.id}: ${message.messageType} - ${message.messageText}');
      }

      print('✅ Message deletion test completed');
    } catch (e) {
      print('❌ Message deletion test failed: $e');
    }
  }

  /// Test method to verify database deletion directly
  static Future<void> testDatabaseDeletion(String messageId) async {
    try {
      print('🧪 Testing database deletion for message: $messageId');

      // Try to fetch the message
      final response = await _supabase
          .from('messages')
          .select('id, sender_id, message_text')
          .eq('id', messageId)
          .maybeSingle();

      if (response != null) {
        print('⚠️ Message still exists in database:');
        print('  - ID: ${response['id']}');
        print('  - Sender: ${response['sender_id']}');
        print('  - Text: ${response['message_text']}');
      } else {
        print('✅ Message does not exist in database (deleted successfully)');
      }

      print('✅ Database deletion test completed');
    } catch (e) {
      print('❌ Database deletion test failed: $e');
    }
  }
}
