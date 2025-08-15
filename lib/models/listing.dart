class Listing {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double? price; // null for donations
  final ListingType type;
  final ListingCategory category;
  final ListingCondition? condition; // for physical items
  final List<String> images;
  final List<String> tags;
  final String? subject;
  final String? courseCode;
  final String? university;
  final String? author; // for books
  final String? isbn; // for books
  final String? edition; // for books
  final String? fileUrl; // for digital resources
  final String? pickupLocation;
  final double? latitude; // Location coordinates
  final double? longitude; // Location coordinates
  final bool allowShipping;
  final ListingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int views;
  final int favorites;

  Listing({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.price,
    required this.type,
    required this.category,
    this.condition,
    required this.images,
    required this.tags,
    this.subject,
    this.courseCode,
    this.university,
    this.author,
    this.isbn,
    this.edition,
    this.fileUrl,
    this.pickupLocation,
    this.latitude,
    this.longitude,
    required this.allowShipping,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.views,
    required this.favorites,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      price: json['price']?.toDouble(),
      type: ListingType.values.firstWhere((e) => e.name == json['type']),
      category:
          ListingCategory.values.firstWhere((e) => e.name == json['category']),
      condition: json['condition'] != null
          ? ListingCondition.values
              .firstWhere((e) => e.name == json['condition'])
          : null,
      images: List<String>.from(json['images'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      subject: json['subject'],
      courseCode: json['course_code'],
      university: json['university'],
      author: json['author'],
      isbn: json['isbn'],
      edition: json['edition'],
      fileUrl: json['file_url'],
      pickupLocation: json['pickup_location'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      allowShipping: json['allow_shipping'] ?? false,
      status: ListingStatus.values.firstWhere((e) => e.name == json['status']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      views: json['views'] ?? 0,
      favorites: json['favorites'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'price': price,
      'type': type.name,
      'category': category.name,
      'condition': condition?.name,
      'images': images,
      'tags': tags,
      'subject': subject,
      'course_code': courseCode,
      'university': university,
      'author': author,
      'isbn': isbn,
      'edition': edition,
      'file_url': fileUrl,
      'pickup_location': pickupLocation,
      'latitude': latitude,
      'longitude': longitude,
      'allow_shipping': allowShipping,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'views': views,
      'favorites': favorites,
    };
  }

  bool get isDonation => price == null || price == 0;
  bool get isPhysical =>
      type == ListingType.book || type == ListingType.equipment;
  bool get isDigital =>
      type == ListingType.notes ||
      type == ListingType.pastPapers ||
      type == ListingType.studyGuides;
  bool get hasCoordinates => latitude != null && longitude != null;
}

enum ListingType { book, notes, pastPapers, studyGuides, equipment, other }

enum ListingCategory {
  // Academic Subjects
  mathematics,
  physics,
  chemistry,
  biology,
  computerScience,
  engineering,
  medicine,
  business,
  economics,
  psychology,
  history,
  literature,
  languages,
  arts,
  law,

  // Book Categories
  textbooks,
  fiction,
  nonFiction,
  reference,

  // Equipment
  calculators,
  labEquipment,
  stationery,

  // Other
  other
}

enum ListingCondition { likeNew, excellent, good, fair, poor }

enum ListingStatus { active, sold, reserved, inactive, deleted }

// Extension for user-friendly display names
extension ListingTypeExtension on ListingType {
  String get displayName {
    switch (this) {
      case ListingType.book:
        return 'Book';
      case ListingType.notes:
        return 'Notes';
      case ListingType.pastPapers:
        return 'Past Papers';
      case ListingType.studyGuides:
        return 'Study Guides';
      case ListingType.equipment:
        return 'Equipment';
      case ListingType.other:
        return 'Other';
    }
  }
}

extension ListingCategoryExtension on ListingCategory {
  String get displayName {
    switch (this) {
      case ListingCategory.mathematics:
        return 'Mathematics';
      case ListingCategory.physics:
        return 'Physics';
      case ListingCategory.chemistry:
        return 'Chemistry';
      case ListingCategory.biology:
        return 'Biology';
      case ListingCategory.computerScience:
        return 'Computer Science';
      case ListingCategory.engineering:
        return 'Engineering';
      case ListingCategory.medicine:
        return 'Medicine';
      case ListingCategory.business:
        return 'Business';
      case ListingCategory.economics:
        return 'Economics';
      case ListingCategory.psychology:
        return 'Psychology';
      case ListingCategory.history:
        return 'History';
      case ListingCategory.literature:
        return 'Literature';
      case ListingCategory.languages:
        return 'Languages';
      case ListingCategory.arts:
        return 'Arts';
      case ListingCategory.law:
        return 'Law';
      case ListingCategory.textbooks:
        return 'Textbooks';
      case ListingCategory.fiction:
        return 'Fiction';
      case ListingCategory.nonFiction:
        return 'Non-Fiction';
      case ListingCategory.reference:
        return 'Reference';
      case ListingCategory.calculators:
        return 'Calculators';
      case ListingCategory.labEquipment:
        return 'Lab Equipment';
      case ListingCategory.stationery:
        return 'Stationery';
      case ListingCategory.other:
        return 'Other';
    }
  }
}

extension ListingConditionExtension on ListingCondition {
  String get displayName {
    switch (this) {
      case ListingCondition.likeNew:
        return 'Like New';
      case ListingCondition.excellent:
        return 'Excellent';
      case ListingCondition.good:
        return 'Good';
      case ListingCondition.fair:
        return 'Fair';
      case ListingCondition.poor:
        return 'Poor';
    }
  }
}

extension ListingStatusExtension on ListingStatus {
  String get displayName {
    switch (this) {
      case ListingStatus.active:
        return 'Available';
      case ListingStatus.sold:
        return 'Sold';
      case ListingStatus.reserved:
        return 'Reserved';
      case ListingStatus.inactive:
        return 'Inactive';
      case ListingStatus.deleted:
        return 'Deleted';
    }
  }
}
