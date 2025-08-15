import 'package:flutter/material.dart';

class StudyResource {
  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String fileType;
  final String subject;
  final String uploaderId;
  final String uploaderName;
  final String uploaderAvatar;
  final int downloadCount;
  final int likeCount;
  final bool isLiked;
  final bool isBookmarked;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? thumbnailUrl;
  final int fileSize; // in bytes

  StudyResource({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.fileType,
    required this.subject,
    required this.uploaderId,
    required this.uploaderName,
    required this.uploaderAvatar,
    required this.downloadCount,
    required this.likeCount,
    required this.isLiked,
    required this.isBookmarked,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.thumbnailUrl,
    required this.fileSize,
  });

  factory StudyResource.fromJson(Map<String, dynamic> json) {
    return StudyResource(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      fileUrl: json['file_url'] as String,
      fileType: json['file_type'] as String,
      subject: json['subject'] as String,
      uploaderId: json['uploader_id'] as String,
      uploaderName: json['uploader_name'] as String? ?? 'Unknown',
      uploaderAvatar: json['uploader_avatar'] as String? ?? '',
      downloadCount: json['download_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      tags: List<String>.from(json['tags'] ?? []),
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileSize: json['file_size'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'file_type': fileType,
      'subject': subject,
      'uploader_id': uploaderId,
      'uploader_name': uploaderName,
      'uploader_avatar': uploaderAvatar,
      'download_count': downloadCount,
      'like_count': likeCount,
      'is_liked': isLiked,
      'is_bookmarked': isBookmarked,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tags': tags,
      'thumbnail_url': thumbnailUrl,
      'file_size': fileSize,
    };
  }

  StudyResource copyWith({
    String? id,
    String? title,
    String? description,
    String? fileUrl,
    String? fileType,
    String? subject,
    String? uploaderId,
    String? uploaderName,
    String? uploaderAvatar,
    int? downloadCount,
    int? likeCount,
    bool? isLiked,
    bool? isBookmarked,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? thumbnailUrl,
    int? fileSize,
  }) {
    return StudyResource(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      subject: subject ?? this.subject,
      uploaderId: uploaderId ?? this.uploaderId,
      uploaderName: uploaderName ?? this.uploaderName,
      uploaderAvatar: uploaderAvatar ?? this.uploaderAvatar,
      downloadCount: downloadCount ?? this.downloadCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  String get formattedFileSize {
    if (fileSize < 1024) {
      return '${fileSize} B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  IconData get fileTypeIcon {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }
}
