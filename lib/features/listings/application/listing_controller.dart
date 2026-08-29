import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/listing_repository.dart';
import '../domain/listing.dart';

final myListingsProvider = FutureProvider<List<Listing>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(listingRepositoryProvider).fetchMyListings(user.id);
});
