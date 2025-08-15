class StudyGroup {
  final String id;
  final String name;
  final String description;
  final String subject;
  final String creatorId;
  final String creatorName;
  final String creatorAvatar;
  final bool isPrivate;
  final int memberCount;
  final int maxMembers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? coverImageUrl;
  final bool isMember;
  final String? role; // 'admin', 'moderator', 'member'

  StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.subject,
    required this.creatorId,
    required this.creatorName,
    required this.creatorAvatar,
    required this.isPrivate,
    required this.memberCount,
    required this.maxMembers,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.coverImageUrl,
    required this.isMember,
    this.role,
  });

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    final memberCount = json['member_count'] as int? ?? 0;
    print(
        '🔍 StudyGroup.fromJson - Group: ${json['name']}, Member count: $memberCount');

    return StudyGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      subject: json['subject'] as String,
      creatorId: json['creator_id'] as String,
      creatorName: json['creator_name'] as String? ?? 'Unknown',
      creatorAvatar: json['creator_avatar'] as String? ?? '',
      isPrivate: json['is_private'] as bool? ?? false,
      memberCount: memberCount,
      maxMembers: json['max_members'] as int? ?? 50,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      tags: List<String>.from(json['tags'] ?? []),
      coverImageUrl: json['cover_image_url'] as String?,
      isMember: json['is_member'] as bool? ?? false,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'subject': subject,
      'creator_id': creatorId,
      'creator_name': creatorName,
      'creator_avatar': creatorAvatar,
      'is_private': isPrivate,
      'member_count': memberCount,
      'max_members': maxMembers,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tags': tags,
      'cover_image_url': coverImageUrl,
      'is_member': isMember,
      'role': role,
    };
  }

  StudyGroup copyWith({
    String? id,
    String? name,
    String? description,
    String? subject,
    String? creatorId,
    String? creatorName,
    String? creatorAvatar,
    bool? isPrivate,
    int? memberCount,
    int? maxMembers,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? coverImageUrl,
    bool? isMember,
    String? role,
  }) {
    return StudyGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorAvatar: creatorAvatar ?? this.creatorAvatar,
      isPrivate: isPrivate ?? this.isPrivate,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isMember: isMember ?? this.isMember,
      role: role ?? this.role,
    );
  }
}
