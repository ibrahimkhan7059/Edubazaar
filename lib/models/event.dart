class Event {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime startDateTime;
  final DateTime? endDateTime;
  final String location;
  final String? locationDetails;
  final String organizerId;
  final String organizerName;
  final String? organizerAvatar;
  final String category;
  final int maxAttendees;
  final int currentAttendees;
  final bool isPublic;
  final bool requiresApproval;
  final List<String>? tags;
  final String? meetingLink;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAttending;
  final String? attendeeStatus; // 'pending', 'approved', 'declined'

  Event({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.startDateTime,
    this.endDateTime,
    required this.location,
    this.locationDetails,
    required this.organizerId,
    required this.organizerName,
    this.organizerAvatar,
    required this.category,
    required this.maxAttendees,
    this.currentAttendees = 0,
    this.isPublic = true,
    this.requiresApproval = false,
    this.tags,
    this.meetingLink,
    required this.createdAt,
    required this.updatedAt,
    this.isAttending = false,
    this.attendeeStatus,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      startDateTime: DateTime.parse(json['start_date_time']),
      endDateTime: json['end_date_time'] != null
          ? DateTime.parse(json['end_date_time'])
          : null,
      location: json['location'] ?? '',
      locationDetails: json['location_details'],
      organizerId: json['organizer_id'] ?? '',
      organizerName: json['organizer_name'] ?? '',
      organizerAvatar: json['organizer_avatar'],
      category: json['category'] ?? '',
      maxAttendees: json['max_attendees'] ?? 0,
      currentAttendees: json['current_attendees'] ?? 0,
      isPublic: json['is_public'] ?? true,
      requiresApproval: json['requires_approval'] ?? false,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      meetingLink: json['meeting_link'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isAttending: json['is_attending'] ?? false,
      attendeeStatus: json['attendee_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'start_date_time': startDateTime.toIso8601String(),
      'end_date_time': endDateTime?.toIso8601String(),
      'location': location,
      'location_details': locationDetails,
      'organizer_id': organizerId,
      'organizer_name': organizerName,
      'organizer_avatar': organizerAvatar,
      'category': category,
      'max_attendees': maxAttendees,
      'current_attendees': currentAttendees,
      'is_public': isPublic,
      'requires_approval': requiresApproval,
      'tags': tags,
      'meeting_link': meetingLink,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_attending': isAttending,
      'attendee_status': attendeeStatus,
    };
  }

  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? location,
    String? locationDetails,
    String? organizerId,
    String? organizerName,
    String? organizerAvatar,
    String? category,
    int? maxAttendees,
    int? currentAttendees,
    bool? isPublic,
    bool? requiresApproval,
    List<String>? tags,
    String? meetingLink,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAttending,
    String? attendeeStatus,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      location: location ?? this.location,
      locationDetails: locationDetails ?? this.locationDetails,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerAvatar: organizerAvatar ?? this.organizerAvatar,
      category: category ?? this.category,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      currentAttendees: currentAttendees ?? this.currentAttendees,
      isPublic: isPublic ?? this.isPublic,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      tags: tags ?? this.tags,
      meetingLink: meetingLink ?? this.meetingLink,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAttending: isAttending ?? this.isAttending,
      attendeeStatus: attendeeStatus ?? this.attendeeStatus,
    );
  }

  // Helper methods
  bool get isPast => DateTime.now().isAfter(endDateTime ?? startDateTime);
  bool get isToday {
    final now = DateTime.now();
    final eventDate = startDateTime;
    return now.year == eventDate.year &&
        now.month == eventDate.month &&
        now.day == eventDate.day;
  }

  bool get isFull => currentAttendees >= maxAttendees;
  bool get canJoin => !isPast && !isFull && !isAttending && !isPending;
  bool get isPending => attendeeStatus == 'pending';
  bool get isApproved => attendeeStatus == 'approved';

  Duration get timeUntilStart => startDateTime.difference(DateTime.now());
  Duration get duration =>
      (endDateTime ?? startDateTime.add(const Duration(hours: 1)))
          .difference(startDateTime);
}
