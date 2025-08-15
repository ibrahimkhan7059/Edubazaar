class UserReview {
  final String id;
  final String reviewerId;
  final String reviewedId;
  final String? listingId;
  final int rating;
  final String? reviewText;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional fields (populated from joins)
  final String? reviewerName;
  final String? reviewerProfilePic;
  final String? listingTitle;

  const UserReview({
    required this.id,
    required this.reviewerId,
    required this.reviewedId,
    this.listingId,
    required this.rating,
    this.reviewText,
    this.isAnonymous = false,
    required this.createdAt,
    required this.updatedAt,
    this.reviewerName,
    this.reviewerProfilePic,
    this.listingTitle,
  });

  // Create from JSON (from Supabase)
  factory UserReview.fromJson(Map<String, dynamic> json) {
    return UserReview(
      id: json['id'] as String,
      reviewerId: json['reviewer_id'] as String,
      reviewedId: json['reviewed_id'] as String,
      listingId: json['listing_id'] as String?,
      rating: json['rating'] as int,
      reviewText: json['review_text'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      reviewerName: json['reviewer_name'] as String?,
      reviewerProfilePic: json['reviewer_profile_pic'] as String?,
      listingTitle: json['listing_title'] as String?,
    );
  }

  // Convert to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reviewer_id': reviewerId,
      'reviewed_id': reviewedId,
      'listing_id': listingId,
      'rating': rating,
      'review_text': reviewText,
      'is_anonymous': isAnonymous,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  UserReview copyWith({
    String? id,
    String? reviewerId,
    String? reviewedId,
    String? listingId,
    int? rating,
    String? reviewText,
    bool? isAnonymous,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reviewerName,
    String? reviewerProfilePic,
    String? listingTitle,
  }) {
    return UserReview(
      id: id ?? this.id,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewedId: reviewedId ?? this.reviewedId,
      listingId: listingId ?? this.listingId,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerProfilePic: reviewerProfilePic ?? this.reviewerProfilePic,
      listingTitle: listingTitle ?? this.listingTitle,
    );
  }

  // Helper getters
  String get displayReviewerName {
    if (isAnonymous) return 'Anonymous';
    return reviewerName ?? 'Unknown User';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  bool get hasText => reviewText != null && reviewText!.isNotEmpty;

  String get ratingStars {
    return '★' * rating + '☆' * (5 - rating);
  }

  @override
  String toString() {
    return 'UserReview(id: $id, rating: $rating, reviewer: $reviewerName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserReview && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
 