import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/review_repository.dart';
import '../domain/review.dart';

final listingReviewsProvider = FutureProvider.family<List<Review>, String>((ref, listingId) {
  return ref.watch(reviewRepositoryProvider).fetchReviewsForListing(listingId);
});

final bookingReviewProvider = FutureProvider.family<Review?, String>((ref, bookingId) {
  return ref.watch(reviewRepositoryProvider).fetchReviewForBooking(bookingId);
});
