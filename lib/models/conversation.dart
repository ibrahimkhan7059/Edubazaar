
class Conversation {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final String? listingId;
  final String? lastMessageId;
  final DateTime lastMessageAt;
  final int participant1UnreadCount;
  final int participant2UnreadCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional properties from view
  final String? participant1Name;
  final String? participant1Avatar;
  final String? participant2Name;
  final String? participant2Avatar;
  final String? lastMessageText;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final String? listingTitle;
  final List<String>? listingImages;

  Conversation({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    this.listingId,
    this.lastMessageId,
    required this.lastMessageAt,
    required this.participant1UnreadCount,
    required this.participant2UnreadCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.participant1Name,
    this.participant1Avatar,
    this.participant2Name,
    this.participant2Avatar,
    this.lastMessageText,
    this.lastMessageType,
    this.lastMessageSenderId,
    this.listingTitle,
    this.listingImages,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      participant1Id: json['participant_1_id'] as String,
      participant2Id: json['participant_2_id'] as String,
      listingId: json['listing_id'] as String?,
      lastMessageId: json['last_message_id'] as String?,
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      participant1UnreadCount: json['participant_1_unread_count'] as int? ?? 0,
      participant2UnreadCount: json['participant_2_unread_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Additional fields from conversation_details view
      participant1Name: json['participant_1_name'] as String?,
      participant1Avatar: json['participant_1_avatar'] as String?,
      participant2Name: json['participant_2_name'] as String?,
      participant2Avatar: json['participant_2_avatar'] as String?,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageType: json['last_message_type'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      listingTitle: json['listing_title'] as String?,
      listingImages: json['listing_images'] != null
          ? List<String>.from(json['listing_images'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participant_1_id': participant1Id,
      'participant_2_id': participant2Id,
      'listing_id': listingId,
      'last_message_id': lastMessageId,
      'last_message_at': lastMessageAt.toIso8601String(),
      'participant_1_unread_count': participant1UnreadCount,
      'participant_2_unread_count': participant2UnreadCount,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  String getOtherParticipantId(String currentUserId) {
    return currentUserId == participant1Id ? participant2Id : participant1Id;
  }

  String? getOtherParticipantName(String currentUserId) {
    return currentUserId == participant1Id
        ? participant2Name
        : participant1Name;
  }

  String? getOtherParticipantAvatar(String currentUserId) {
    return currentUserId == participant1Id
        ? participant2Avatar
        : participant1Avatar;
  }

  int getUnreadCount(String currentUserId) {
    return currentUserId == participant1Id
        ? participant1UnreadCount
        : participant2UnreadCount;
  }

  bool hasUnreadMessages(String currentUserId) {
    return getUnreadCount(currentUserId) > 0;
  }

  // Create a copy with updated values
  Conversation copyWith({
    String? id,
    String? participant1Id,
    String? participant2Id,
    String? listingId,
    String? lastMessageId,
    DateTime? lastMessageAt,
    int? participant1UnreadCount,
    int? participant2UnreadCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? participant1Name,
    String? participant1Avatar,
    String? participant2Name,
    String? participant2Avatar,
    String? lastMessageText,
    String? lastMessageType,
    String? lastMessageSenderId,
    String? listingTitle,
    List<String>? listingImages,
  }) {
    return Conversation(
      id: id ?? this.id,
      participant1Id: participant1Id ?? this.participant1Id,
      participant2Id: participant2Id ?? this.participant2Id,
      listingId: listingId ?? this.listingId,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      participant1UnreadCount:
          participant1UnreadCount ?? this.participant1UnreadCount,
      participant2UnreadCount:
          participant2UnreadCount ?? this.participant2UnreadCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participant1Name: participant1Name ?? this.participant1Name,
      participant1Avatar: participant1Avatar ?? this.participant1Avatar,
      participant2Name: participant2Name ?? this.participant2Name,
      participant2Avatar: participant2Avatar ?? this.participant2Avatar,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingImages: listingImages ?? this.listingImages,
    );
  }

  @override
  String toString() {
    return 'Conversation(id: $id, participants: [$participant1Id, $participant2Id], lastMessage: $lastMessageText)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
