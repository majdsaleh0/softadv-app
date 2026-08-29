class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.rating,
    required this.comment,
    required this.providerReply,
    required this.createdAt,
    required this.customerName,
  });

  final String id;
  final String bookingId;
  final String customerId;
  final int rating;
  final String? comment;
  final String? providerReply;
  final DateTime createdAt;
  final String customerName;

  factory Review.fromMap(Map<String, dynamic> map) {
    final customer = map['customer'] as Map<String, dynamic>?;
    return Review(
      id: map['id'] as String,
      bookingId: map['booking_id'] as String,
      customerId: map['customer_id'] as String,
      rating: map['rating'] as int,
      comment: map['comment'] as String?,
      providerReply: map['provider_reply'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      customerName: customer?['name'] as String? ?? '',
    );
  }
}
