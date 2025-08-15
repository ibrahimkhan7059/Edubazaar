class GroupPost {
  final String id;
  final String groupId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String postType; // 'discussion', 'announcement', 'question', 'resource'
  final String? title;
  final String content;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final int likeCount;
  final int commentCount;
  final bool isPinned;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isLiked; // Whether current user has liked this post

  GroupPost({
    required this.id,
    required this.groupId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.postType,
    this.title,
    required this.content,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isPinned = false,
    this.isEdited = false,
    this.editedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isLiked = false,
  });

  factory GroupPost.fromJson(Map<String, dynamic> json) {
    return GroupPost(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String,
      authorAvatar: json['author_avatar'] as String?,
      postType: json['post_type'] as String,
      title: json['title'] as String?,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
      isEdited: json['is_edited'] as bool? ?? false,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'post_type': postType,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'like_count': likeCount,
      'comment_count': commentCount,
      'is_pinned': isPinned,
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_liked': isLiked,
    };
  }

  GroupPost copyWith({
    String? id,
    String? groupId,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? postType,
    String? title,
    String? content,
    String? imageUrl,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    int? likeCount,
    int? commentCount,
    bool? isPinned,
    bool? isEdited,
    DateTime? editedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isLiked,
  }) {
    return GroupPost(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      postType: postType ?? this.postType,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isPinned: isPinned ?? this.isPinned,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class GroupPostComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final bool isEdited;
  final DateTime? editedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupPostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.isEdited = false,
    this.editedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupPostComment.fromJson(Map<String, dynamic> json) {
    return GroupPostComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String,
      authorAvatar: json['author_avatar'] as String?,
      content: json['content'] as String,
      isEdited: json['is_edited'] as bool? ?? false,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'content': content,
      'is_edited': isEdited,
      'edited_at': editedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
