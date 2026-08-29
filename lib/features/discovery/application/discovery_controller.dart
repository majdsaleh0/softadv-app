import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listings/domain/listing.dart';
import '../data/discovery_repository.dart';
import '../domain/provider_profile.dart';
import '../domain/search_filters.dart';
import '../domain/sort_option.dart';

class SearchFiltersNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => const SearchFilters();

  void setKeyword(String? keyword) {
    state = SearchFilters(keyword: keyword, category: state.category, location: state.location, minRating: state.minRating, sort: state.sort);
  }

  void setSort(SortOption sort) {
    state = SearchFilters(keyword: state.keyword, category: state.category, location: state.location, minRating: state.minRating, sort: sort);
  }

  void applyFilters({ListingCategory? category, String? location, double? minRating}) {
    state = SearchFilters(keyword: state.keyword, category: category, location: location, minRating: minRating, sort: state.sort);
  }
}

final searchFiltersProvider = NotifierProvider<SearchFiltersNotifier, SearchFilters>(SearchFiltersNotifier.new);

final searchResultsProvider = FutureProvider<List<Listing>>((ref) {
  final filters = ref.watch(searchFiltersProvider);
  return ref.watch(discoveryRepositoryProvider).searchListings(
    keyword: filters.keyword,
    category: filters.category,
    location: filters.location,
    minRating: filters.minRating,
    sort: filters.sort,
  );
});

final listingDetailProvider = FutureProvider.family<Listing, String>((ref, listingId) {
  return ref.watch(discoveryRepositoryProvider).fetchListing(listingId);
});

final providerProfileProvider = FutureProvider.family<ProviderProfile, String>((ref, providerId) {
  return ref.watch(discoveryRepositoryProvider).fetchProviderProfile(providerId);
});

final providerListingsProvider = FutureProvider.family<List<Listing>, String>((ref, providerId) {
  return ref.watch(discoveryRepositoryProvider).fetchProviderActiveListings(providerId);
});
