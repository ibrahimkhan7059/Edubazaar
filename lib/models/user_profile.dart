class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? profilePicUrl;
  final String? coverPhotoUrl;
  final String? university;
  final String? course;
  final String? semester;
  final String? bio;
  final String? phoneNumber;
  final DateTime joinedDate;
  final int totalListings;
  final int totalSales;
  final double rating;
  final List<String> interests;
  final bool isVerified;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.profilePicUrl,
    this.coverPhotoUrl,
    this.university,
    this.course,
    this.semester,
    this.bio,
    this.phoneNumber,
    required this.joinedDate,
    this.totalListings = 0,
    this.totalSales = 0,
    this.rating = 0.0,
    this.interests = const [],
    this.isVerified = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      profilePicUrl: json['profile_pic_url'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      university: json['university'] as String?,
      course: json['course'] as String?,
      semester: json['semester'] as String?,
      bio: json['bio'] as String?,
      phoneNumber: json['phone_number'] as String?,
      joinedDate: DateTime.parse(json['joined_date'] as String),
      totalListings: json['total_listings'] as int? ?? 0,
      totalSales: json['total_sales'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'name': name,
      'email': email,
      'profile_pic_url': profilePicUrl,
      'cover_photo_url': coverPhotoUrl,
      'university': university,
      'course': course,
      'semester': semester,
      'bio': bio,
      'phone_number': phoneNumber,
      'joined_date': joinedDate.toIso8601String(),
      'total_listings': totalListings,
      'total_sales': totalSales,
      'rating': rating,
      'interests': interests,
      'is_verified': isVerified,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    String? profilePicUrl,
    String? coverPhotoUrl,
    String? university,
    String? course,
    String? semester,
    String? bio,
    String? phoneNumber,
    DateTime? joinedDate,
    int? totalListings,
    int? totalSales,
    double? rating,
    List<String>? interests,
    bool? isVerified,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      university: university ?? this.university,
      course: course ?? this.course,
      semester: semester ?? this.semester,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      joinedDate: joinedDate ?? this.joinedDate,
      totalListings: totalListings ?? this.totalListings,
      totalSales: totalSales ?? this.totalSales,
      rating: rating ?? this.rating,
      interests: interests ?? this.interests,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
