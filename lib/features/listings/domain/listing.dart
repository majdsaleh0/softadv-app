enum ListingCategory { homeRepair, tutoring, cleaning, beauty, other }

const _categoryDbValues = {
  ListingCategory.homeRepair: 'home_repair',
  ListingCategory.tutoring: 'tutoring',
  ListingCategory.cleaning: 'cleaning',
  ListingCategory.beauty: 'beauty',
  ListingCategory.other: 'other',
};

extension ListingCategoryDb on ListingCategory {
  String get dbValue => _categoryDbValues[this]!;

  String get label => switch (this) {
    ListingCategory.homeRepair => 'Home Repair',
    ListingCategory.tutoring => 'Tutoring',
    ListingCategory.cleaning => 'Cleaning',
    ListingCategory.beauty => 'Beauty',
    ListingCategory.other => 'Other',
  };
}

ListingCategory listingCategoryFromDb(String value) {
  return _categoryDbValues.entries.firstWhere((e) => e.value == value, orElse: () => const MapEntry(ListingCategory.other, 'other')).key;
}

enum ListingStatus { pending, approved, rejected }

ListingStatus listingStatusFromDb(String value) {
  return ListingStatus.values.firstWhere((s) => s.name == value, orElse: () => ListingStatus.pending);
}

class Listing {
  const Listing({
    required this.id,
    required this.providerId,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.price,
    required this.status,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.avgRating,
    this.reviewCount = 0,
    this.removedByAdmin = false,
  });

  final String id;
  final String providerId;
  final String title;
  final String description;
  final ListingCategory category;
  final String location;
  final double price;
  final ListingStatus status;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null until G5 populates it from reviews.
  final double? avgRating;
  final int reviewCount;

  /// FR-41: admin moderation removal, distinct from the provider's own is_active toggle.
  final bool removedByAdmin;

  factory Listing.fromMap(Map<String, dynamic> map) {
    return Listing(
      id: map['id'] as String,
      providerId: map['provider_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: listingCategoryFromDb(map['category'] as String),
      location: map['location'] as String,
      price: (map['price'] as num).toDouble(),
      status: listingStatusFromDb(map['status'] as String),
      isActive: map['is_active'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      avgRating: (map['avg_rating'] as num?)?.toDouble(),
      reviewCount: map['review_count'] as int? ?? 0,
      removedByAdmin: map['removed_by_admin'] as bool? ?? false,
    );
  }
}
