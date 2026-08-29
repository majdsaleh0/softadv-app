import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listings/data/listing_repository.dart';
import '../../listings/domain/listing.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile.dart';

final allListingsProvider = FutureProvider<List<Listing>>((ref) {
  return ref.watch(listingRepositoryProvider).fetchAllListings();
});

final allProfilesProvider = FutureProvider<List<Profile>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchAllProfiles();
});
