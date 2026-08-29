import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../listings/domain/listing.dart';
import '../domain/provider_profile.dart';
import '../domain/sort_option.dart';

class DiscoveryRepository {
  DiscoveryRepository(this._client);

  final SupabaseClient _client;

  Future<List<Listing>> searchListings({
    String? keyword,
    ListingCategory? category,
    String? location,
    double? minRating,
    SortOption sort = SortOption.newest,
  }) async {
    var query = _client.from('listings').select().eq('status', 'approved').eq('is_active', true);

    final trimmedKeyword = keyword?.trim();
    if (trimmedKeyword != null && trimmedKeyword.isNotEmpty) {
      final term = '%$trimmedKeyword%';
      query = query.or('title.ilike.$term,description.ilike.$term,category.ilike.$term');
    }
    if (category != null) {
      query = query.eq('category', category.dbValue);
    }
    final trimmedLocation = location?.trim();
    if (trimmedLocation != null && trimmedLocation.isNotEmpty) {
      query = query.ilike('location', '%$trimmedLocation%');
    }
    if (minRating != null) {
      query = query.gte('avg_rating', minRating);
    }

    final ordered = switch (sort) {
      SortOption.newest => query.order('created_at', ascending: false),
      SortOption.priceLowToHigh => query.order('price', ascending: true),
      SortOption.priceHighToLow => query.order('price', ascending: false),
      SortOption.rating => query.order('avg_rating', ascending: false, nullsFirst: false),
    };

    final rows = await ordered;
    return (rows as List).map((row) => Listing.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<Listing> fetchListing(String id) async {
    final row = await _client.from('listings').select().eq('id', id).single();
    return Listing.fromMap(row);
  }

  Future<ProviderProfile> fetchProviderProfile(String providerId) async {
    final row = await _client.from('provider_public_profiles').select().eq('id', providerId).single();
    return ProviderProfile.fromMap(row);
  }

  Future<List<Listing>> fetchProviderActiveListings(String providerId) async {
    final rows = await _client
        .from('listings')
        .select()
        .eq('provider_id', providerId)
        .eq('status', 'approved')
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (rows as List).map((row) => Listing.fromMap(row as Map<String, dynamic>)).toList();
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  return DiscoveryRepository(ref.watch(supabaseClientProvider));
});
