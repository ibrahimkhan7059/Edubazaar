enum TransactionStatus {
  pending,
  completed,
  cancelled,
  disputed;

  String get displayName {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
      case TransactionStatus.disputed:
        return 'Disputed';
    }
  }
}

enum TransactionType {
  sale,
  purchase,
  donation;

  String get displayName {
    switch (this) {
      case TransactionType.sale:
        return 'Sale';
      case TransactionType.purchase:
        return 'Purchase';
      case TransactionType.donation:
        return 'Donation';
    }
  }
}

class UserTransaction {
  final String id;
  final String sellerId;
  final String buyerId;
  final String listingId;
  final DateTime transactionDate;
  final TransactionStatus status;
  final TransactionType transactionType;
  final double amount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional fields (populated from joins)
  final String? sellerName;
  final String? sellerProfilePic;
  final String? buyerName;
  final String? buyerProfilePic;
  final String? listingTitle;
  final String? listingImage;

  const UserTransaction({
    required this.id,
    required this.sellerId,
    required this.buyerId,
    required this.listingId,
    required this.transactionDate,
    required this.status,
    required this.transactionType,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.sellerName,
    this.sellerProfilePic,
    this.buyerName,
    this.buyerProfilePic,
    this.listingTitle,
    this.listingImage,
  });

  // Create from JSON (from Supabase)
  factory UserTransaction.fromJson(Map<String, dynamic> json) {
    return UserTransaction(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      buyerId: json['buyer_id'] as String,
      listingId: json['listing_id'] as String,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      transactionType: TransactionType.values.firstWhere(
        (e) => e.name == json['transaction_type'],
        orElse: () => TransactionType.sale,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sellerName: json['seller_name'] as String?,
      sellerProfilePic: json['seller_profile_pic'] as String?,
      buyerName: json['buyer_name'] as String?,
      buyerProfilePic: json['buyer_profile_pic'] as String?,
      listingTitle: json['listing_title'] as String?,
      listingImage: json['listing_image'] as String?,
    );
  }

  // Convert to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_id': sellerId,
      'buyer_id': buyerId,
      'listing_id': listingId,
      'transaction_date': transactionDate.toIso8601String(),
      'status': status.name,
      'transaction_type': transactionType.name,
      'amount': amount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  UserTransaction copyWith({
    String? id,
    String? sellerId,
    String? buyerId,
    String? listingId,
    DateTime? transactionDate,
    TransactionStatus? status,
    TransactionType? transactionType,
    double? amount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sellerName,
    String? sellerProfilePic,
    String? buyerName,
    String? buyerProfilePic,
    String? listingTitle,
    String? listingImage,
  }) {
    return UserTransaction(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      buyerId: buyerId ?? this.buyerId,
      listingId: listingId ?? this.listingId,
      transactionDate: transactionDate ?? this.transactionDate,
      status: status ?? this.status,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sellerName: sellerName ?? this.sellerName,
      sellerProfilePic: sellerProfilePic ?? this.sellerProfilePic,
      buyerName: buyerName ?? this.buyerName,
      buyerProfilePic: buyerProfilePic ?? this.buyerProfilePic,
      listingTitle: listingTitle ?? this.listingTitle,
      listingImage: listingImage ?? this.listingImage,
    );
  }

  // Helper getters
  String get formattedAmount {
    if (transactionType == TransactionType.donation) {
      return 'FREE';
    }
    return 'Rs. ${amount.toStringAsFixed(0)}';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(transactionDate);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Today';
    }
  }

  String get displayTitle => listingTitle ?? 'Unknown Item';

  String getOtherPartyName(String currentUserId) {
    if (currentUserId == sellerId) {
      return buyerName ?? 'Unknown Buyer';
    } else {
      return sellerName ?? 'Unknown Seller';
    }
  }

  String? getOtherPartyProfilePic(String currentUserId) {
    if (currentUserId == sellerId) {
      return buyerProfilePic;
    } else {
      return sellerProfilePic;
    }
  }

  String getTransactionDescription(String currentUserId) {
    if (currentUserId == sellerId) {
      return 'Sold to ${buyerName ?? 'Unknown'}';
    } else {
      return 'Bought from ${sellerName ?? 'Unknown'}';
    }
  }

  bool isSeller(String currentUserId) => currentUserId == sellerId;
  bool isBuyer(String currentUserId) => currentUserId == buyerId;

  bool get isDonation => transactionType == TransactionType.donation;
  bool get isPending => status == TransactionStatus.pending;
  bool get isCompleted => status == TransactionStatus.completed;
  bool get isCancelled => status == TransactionStatus.cancelled;
  bool get isDisputed => status == TransactionStatus.disputed;

  @override
  String toString() {
    return 'UserTransaction(id: $id, type: $transactionType, amount: $amount, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
 