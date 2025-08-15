enum MessageType {
  text,
  image,
  listingShare,
  system,
}

extension MessageTypeExtension on MessageType {
  String get name {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.listingShare:
        return 'listing_share';
      case MessageType.system:
        return 'system';
    }
  }

  static MessageType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'listing_share':
        return MessageType.listingShare;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String messageText;
  final MessageType messageType;
  final String? attachmentUrl;
  final String? listingReferenceId;
  final bool isRead;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Message status fields
  final bool isDelivered;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  // Message reactions
  final Map<String, String> reactions; // userId -> reactionType

  // Additional properties for UI
  final String? senderName;
  final String? senderAvatar;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.messageText,
    required this.messageType,
    this.attachmentUrl,
    this.listingReferenceId,
    required this.isRead,
    required this.isEdited,
    this.editedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isDelivered = false,
    this.deliveredAt,
    this.readAt,
    this.reactions = const {},
    this.senderName,
    this.senderAvatar,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      messageText: json['message_text'] as String,
      messageType: MessageTypeExtension.fromString(
          json['message_type'] as String? ?? 'text'),
      attachmentUrl: json['attachment_url'] as String?,
      listingReferenceId: json['listing_reference_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      isEdited: json['is_edited'] as bool? ?? false,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDelivered: json['is_delivered'] as bool? ?? false,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          const {},
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_text': messageText,
      'message_type': messageType.name,
      'attachment_url': attachmentUrl,
      'listing_reference_id': listingReferenceId,
      'is_read': isRead,
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'reactions': reactions,
    };
  }

  // Create message for sending (without ID and timestamps)
  Map<String, dynamic> toCreateJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_text': messageText,
      'message_type': messageType.name,
      'attachment_url': attachmentUrl,
      'listing_reference_id': listingReferenceId,
    };
  }

  // Helper methods
  bool isSentByUser(String userId) {
    return senderId == userId;
  }

  bool isTextMessage() {
    return messageType == MessageType.text;
  }

  bool isImageMessage() {
    return messageType == MessageType.image;
  }

  bool isListingShare() {
    return messageType == MessageType.listingShare;
  }

  bool isSystemMessage() {
    return messageType == MessageType.system;
  }

  bool hasAttachment() {
    return attachmentUrl != null && attachmentUrl!.isNotEmpty;
  }

  // Create formatted time string
  String getFormattedTime() {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  // Create time for chat bubbles (12-hour format) - using local timezone
  String getChatTime() {
    // Convert UTC time to local timezone
    final localTime = createdAt.toLocal();

    // Convert to 12-hour format
    int hour = localTime.hour;
    String period = 'AM';

    if (hour >= 12) {
      period = 'PM';
      if (hour > 12) {
        hour = hour - 12;
      }
    }

    // Handle 12 AM case
    if (hour == 0) {
      hour = 12;
    }

    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  // Create a copy with updated values
  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? messageText,
    MessageType? messageType,
    String? attachmentUrl,
    String? listingReferenceId,
    bool? isRead,
    bool? isEdited,
    DateTime? editedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, String>? reactions,
    String? senderName,
    String? senderAvatar,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      messageText: messageText ?? this.messageText,
      messageType: messageType ?? this.messageType,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      listingReferenceId: listingReferenceId ?? this.listingReferenceId,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reactions: reactions ?? this.reactions,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, sender: $senderId, text: $messageText, type: ${messageType.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Factory constructors for different message types
  static Message createTextMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) {
    return Message(
      id: '', // Will be set by database
      conversationId: conversationId,
      senderId: senderId,
      messageText: text,
      messageType: MessageType.text,
      isRead: false,
      isEdited: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Message createImageMessage({
    required String conversationId,
    required String senderId,
    required String imageUrl,
    String caption = '',
  }) {
    return Message(
      id: '', // Will be set by database
      conversationId: conversationId,
      senderId: senderId,
      messageText: caption,
      messageType: MessageType.image,
      attachmentUrl: imageUrl,
      isRead: false,
      isEdited: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Message createListingShare({
    required String conversationId,
    required String senderId,
    required String listingId,
    String? customMessage,
  }) {
    return Message(
      id: '', // Will be set by database
      conversationId: conversationId,
      senderId: senderId,
      messageText: customMessage ?? 'Shared a listing',
      messageType: MessageType.listingShare,
      listingReferenceId: listingId,
      isRead: false,
      isEdited: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  static Message createSystemMessage({
    required String conversationId,
    required String text,
  }) {
    return Message(
      id: '', // Will be set by database
      conversationId: conversationId,
      senderId: 'system', // System messages have 'system' as sender
      messageText: text,
      messageType: MessageType.system,
      isRead: true, // System messages are automatically read
      isEdited: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Message status helper methods
  MessageStatus get status {
    if (readAt != null) {
      return MessageStatus.read;
    } else if (isDelivered) {
      return MessageStatus.delivered;
    } else {
      return MessageStatus.sent;
    }
  }

  bool get isSent => true; // If message exists, it's sent
  bool get isMessageDelivered => isDelivered;
  bool get isMessageRead => readAt != null;

  // Reaction helper methods
  bool hasReaction(String userId) {
    return reactions.containsKey(userId);
  }

  String? getUserReaction(String userId) {
    return reactions[userId];
  }

  List<String> getReactionCounts() {
    final counts = <String, int>{};
    for (final reaction in reactions.values) {
      counts[reaction] = (counts[reaction] ?? 0) + 1;
    }
    return counts.entries.map((e) => '${e.key}${e.value}').toList();
  }

  bool hasReactions() {
    return reactions.isNotEmpty;
  }

  void addReaction(String userId, String reactionType) {
    reactions[userId] = reactionType;
  }

  void removeReaction(String userId) {
    reactions.remove(userId);
  }
}

// Message status enum for UI
enum MessageStatus {
  sent, // Single tick
  delivered, // Double tick
  read, // Blue double tick (seen)
}

// Message reaction types
enum ReactionType {
  like('👍'),
  love('❤️'),
  laugh('😂'),
  wow('😮'),
  sad('😢'),
  angry('😠');

  const ReactionType(this.emoji);
  final String emoji;

  static ReactionType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'like':
        return ReactionType.like;
      case 'love':
        return ReactionType.love;
      case 'laugh':
        return ReactionType.laugh;
      case 'wow':
        return ReactionType.wow;
      case 'sad':
        return ReactionType.sad;
      case 'angry':
        return ReactionType.angry;
      default:
        return ReactionType.like;
    }
  }
}
