class ForumTopic {
  final String id;
  final String title;
  final String content;
  final String category;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final int replyCount;
  final int viewCount;
  final int likeCount;
  final bool isLiked;
  final bool isPinned;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? lastReplyBy;
  final DateTime? lastReplyAt;

  ForumTopic({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.replyCount,
    required this.viewCount,
    required this.likeCount,
    required this.isLiked,
    required this.isPinned,
    required this.isLocked,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.lastReplyBy,
    this.lastReplyAt,
  });

  factory ForumTopic.fromJson(Map<String, dynamic> json) {
    return ForumTopic(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'Unknown',
      authorAvatar: json['author_avatar'] as String? ?? '',
      replyCount: json['reply_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      tags: List<String>.from(json['tags'] ?? []),
      lastReplyBy: json['last_reply_by'] as String?,
      lastReplyAt: json['last_reply_at'] != null
          ? DateTime.parse(json['last_reply_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'reply_count': replyCount,
      'view_count': viewCount,
      'like_count': likeCount,
      'is_liked': isLiked,
      'is_pinned': isPinned,
      'is_locked': isLocked,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tags': tags,
      'last_reply_by': lastReplyBy,
      'last_reply_at': lastReplyAt?.toIso8601String(),
    };
  }

  ForumTopic copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    int? replyCount,
    int? viewCount,
    int? likeCount,
    bool? isLiked,
    bool? isPinned,
    bool? isLocked,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? lastReplyBy,
    DateTime? lastReplyAt,
  }) {
    return ForumTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      replyCount: replyCount ?? this.replyCount,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      lastReplyBy: lastReplyBy ?? this.lastReplyBy,
      lastReplyAt: lastReplyAt ?? this.lastReplyAt,
    );
  }
}
