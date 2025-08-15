class CommunityEvent {
  final String id;
  final String title;
  final String description;
  final DateTime eventDate;
  final String location;
  final String organizerId;
  final String organizerName;
  final String organizerAvatar;
  final int maxParticipants;
  final int currentParticipants;
  final bool isOnline;
  final String? meetingLink;
  final bool isJoined;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? coverImage;
  final String status; // 'upcoming', 'ongoing', 'completed', 'cancelled'

  CommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.location,
    required this.organizerId,
    required this.organizerName,
    required this.organizerAvatar,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.isOnline,
    this.meetingLink,
    required this.isJoined,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.coverImage,
    required this.status,
  });

  factory CommunityEvent.fromJson(Map<String, dynamic> json) {
    return CommunityEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      eventDate: DateTime.parse(json['event_date'] as String),
      location: json['location'] as String,
      organizerId: json['organizer_id'] as String,
      organizerName: json['organizer_name'] as String? ?? 'Unknown',
      organizerAvatar: json['organizer_avatar'] as String? ?? '',
      maxParticipants: json['max_participants'] as int? ?? 50,
      currentParticipants: json['current_participants'] as int? ?? 0,
      isOnline: json['is_online'] as bool? ?? false,
      meetingLink: json['meeting_link'] as String?,
      isJoined: json['is_joined'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      tags: List<String>.from(json['tags'] ?? []),
      coverImage: json['cover_image'] as String?,
      status: json['status'] as String? ?? 'upcoming',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'event_date': eventDate.toIso8601String(),
      'location': location,
      'organizer_id': organizerId,
      'organizer_name': organizerName,
      'organizer_avatar': organizerAvatar,
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
      'is_online': isOnline,
      'meeting_link': meetingLink,
      'is_joined': isJoined,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tags': tags,
      'cover_image': coverImage,
      'status': status,
    };
  }

  CommunityEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? eventDate,
    String? location,
    String? organizerId,
    String? organizerName,
    String? organizerAvatar,
    int? maxParticipants,
    int? currentParticipants,
    bool? isOnline,
    String? meetingLink,
    bool? isJoined,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? coverImage,
    String? status,
  }) {
    return CommunityEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      location: location ?? this.location,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerAvatar: organizerAvatar ?? this.organizerAvatar,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      isOnline: isOnline ?? this.isOnline,
      meetingLink: meetingLink ?? this.meetingLink,
      isJoined: isJoined ?? this.isJoined,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      coverImage: coverImage ?? this.coverImage,
      status: status ?? this.status,
    );
  }

  bool get isFull => currentParticipants >= maxParticipants;
  bool get isUpcoming => eventDate.isAfter(DateTime.now());
  bool get isOngoing =>
      eventDate.isBefore(DateTime.now()) &&
      eventDate.add(const Duration(hours: 3)).isAfter(DateTime.now());
  bool get isCompleted =>
      eventDate.add(const Duration(hours: 3)).isBefore(DateTime.now());

  String get formattedDate {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} from now';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} from now';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} from now';
    } else {
      return 'Starting now';
    }
  }
}
