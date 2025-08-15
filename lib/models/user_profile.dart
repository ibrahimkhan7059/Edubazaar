class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? profilePicUrl;
  final String? coverPhotoUrl;
  final String? university;
  final String? course;
  final String? semester;
  final String? bio;
  final String? phoneNumber;
  final List<String> interests;
  final bool isVerified;
  final bool isActive;
  final DateTime lastActive;
  final DateTime joinedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Stats (from view)
  final int totalListings;
  final int activeListings;
  final int soldListings;
  final double averageRating;
  final int totalReviews;
  final int totalSales;
  final int totalPurchases;
  final int totalDonationsGiven;
  final int totalDonationsReceived;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.profilePicUrl,
    this.coverPhotoUrl,
    this.university,
    this.course,
    this.semester,
    this.bio,
    this.phoneNumber,
    this.interests = const [],
    this.isVerified = false,
    this.isActive = true,
    required this.lastActive,
    required this.joinedDate,
    required this.createdAt,
    required this.updatedAt,
    this.totalListings = 0,
    this.activeListings = 0,
    this.soldListings = 0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.totalSales = 0,
    this.totalPurchases = 0,
    this.totalDonationsGiven = 0,
    this.totalDonationsReceived = 0,
  });

  // Create from JSON (from Supabase)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      profilePicUrl: json['profile_pic_url'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      university: json['university'] as String?,
      course: json['course'] as String?,
      semester: json['semester'] as String?,
      bio: json['bio'] as String?,
      phoneNumber: json['phone_number'] as String?,
      interests: json['interests'] != null
          ? List<String>.from(json['interests'] as List)
          : [],
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      lastActive: DateTime.parse(json['last_active'] as String),
      joinedDate: DateTime.parse(json['joined_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      totalListings: json['total_listings'] as int? ?? 0,
      activeListings: json['active_listings'] as int? ?? 0,
      soldListings: json['sold_listings'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      totalSales: json['total_sales'] as int? ?? 0,
      totalPurchases: json['total_purchases'] as int? ?? 0,
      totalDonationsGiven: json['total_donations_given'] as int? ?? 0,
      totalDonationsReceived: json['total_donations_received'] as int? ?? 0,
    );
  }

  // Convert to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profile_pic_url': profilePicUrl,
      'cover_photo_url': coverPhotoUrl,
      'university': university,
      'course': course,
      'semester': semester,
      'bio': bio,
      'phone_number': phoneNumber,
      'interests': interests,
      'is_verified': isVerified,
      'is_active': isActive,
      'last_active': lastActive.toIso8601String(),
      'joined_date': joinedDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? profilePicUrl,
    String? coverPhotoUrl,
    String? university,
    String? course,
    String? semester,
    String? bio,
    String? phoneNumber,
    List<String>? interests,
    bool? isVerified,
    bool? isActive,
    DateTime? lastActive,
    DateTime? joinedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalListings,
    int? activeListings,
    int? soldListings,
    double? averageRating,
    int? totalReviews,
    int? totalSales,
    int? totalPurchases,
    int? totalDonationsGiven,
    int? totalDonationsReceived,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      university: university ?? this.university,
      course: course ?? this.course,
      semester: semester ?? this.semester,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      interests: interests ?? this.interests,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      lastActive: lastActive ?? this.lastActive,
      joinedDate: joinedDate ?? this.joinedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalListings: totalListings ?? this.totalListings,
      activeListings: activeListings ?? this.activeListings,
      soldListings: soldListings ?? this.soldListings,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      totalSales: totalSales ?? this.totalSales,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalDonationsGiven: totalDonationsGiven ?? this.totalDonationsGiven,
      totalDonationsReceived:
          totalDonationsReceived ?? this.totalDonationsReceived,
    );
  }

  // Helper getters
  String get displayName => name.isNotEmpty ? name : email.split('@').first;

  String get initials {
    if (name.isEmpty) return email.substring(0, 1).toUpperCase();
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, 1).toUpperCase();
  }

  String get memberSince {
    final now = DateTime.now();
    final difference = now.difference(joinedDate);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return 'Today';
    }
  }

  String get lastSeenText {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 5) {
      return 'Online';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return 'Last seen ${difference.inDays} days ago';
    }
  }

  bool get isOnline => DateTime.now().difference(lastActive).inMinutes < 5;

  String get ratingText {
    if (totalReviews == 0) return 'No ratings yet';
    return '${averageRating.toStringAsFixed(1)} ($totalReviews review${totalReviews > 1 ? 's' : ''})';
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, email: $email, university: $university)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
 