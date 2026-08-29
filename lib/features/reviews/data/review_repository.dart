import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/review.dart';

class ReviewRepository {
  ReviewRepository(this._client);

  final SupabaseClient _client;

  static const _selectWithCustomer = '*, customer:profiles!reviews_customer_id_fkey(name)';

  Future<List<Review>> fetchReviewsForListing(String listingId) async {
    final rows = await _client.from('reviews').select('$_selectWithCustomer, bookings!inner(listing_id)').eq('bookings.listing_id', listingId).order('created_at', ascending: false);
    return (rows as List).map((r) => Review.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Review?> fetchReviewForBooking(String bookingId) async {
    final row = await _client.from('reviews').select(_selectWithCustomer).eq('booking_id', bookingId).maybeSingle();
    return row == null ? null : Review.fromMap(row);
  }

  /// For admin report-resolution context (which review is this report about).
  Future<Review?> fetchReviewById(String id) async {
    final row = await _client.from('reviews').select(_selectWithCustomer).eq('id', id).maybeSingle();
    return row == null ? null : Review.fromMap(row);
  }

  /// FR-29. DR-05 (booking must be completed) is enforced by RLS, not here.
  Future<void> submitReview({required String bookingId, required int rating, String? comment}) async {
    final user = _client.auth.currentUser!;
    await _client.from('reviews').insert({'booking_id': bookingId, 'customer_id': user.id, 'rating': rating, 'comment': comment});
  }

  /// FR-30.
  Future<void> updateReview({required String reviewId, required int rating, String? comment}) async {
    await _client.from('reviews').update({'rating': rating, 'comment': comment}).eq('id', reviewId);
  }

  /// FR-31.
  Future<void> deleteReview(String reviewId) async {
    await _client.from('reviews').delete().eq('id', reviewId);
  }

  /// FR-32.
  Future<void> replyToReview({required String reviewId, required String reply}) async {
    await _client.from('reviews').update({'provider_reply': reply}).eq('id', reviewId);
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(supabaseClientProvider));
});
