import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/listing.dart';
import '../domain/listing_image.dart';
import '../domain/listing_time_slot.dart';

class ListingRepository {
  ListingRepository(this._client);

  final SupabaseClient _client;

  static const _imagesBucket = 'listing-images';

  Future<List<Listing>> fetchMyListings(String providerId) async {
    final rows = await _client.from('listings').select().eq('provider_id', providerId).order('created_at', ascending: false);
    return (rows as List).map((row) => Listing.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<Listing> fetchListing(String id) async {
    final row = await _client.from('listings').select().eq('id', id).single();
    return Listing.fromMap(row);
  }

  Future<Listing> createListing({
    required String providerId,
    required String title,
    required String description,
    required ListingCategory category,
    required String location,
    required double price,
  }) async {
    final row = await _client
        .from('listings')
        .insert({
          'provider_id': providerId,
          'title': title,
          'description': description,
          'category': category.dbValue,
          'location': location,
          'price': price,
        })
        .select()
        .single();
    return Listing.fromMap(row);
  }

  Future<Listing> updateListing({
    required String id,
    required String title,
    required String description,
    required ListingCategory category,
    required String location,
    required double price,
  }) async {
    final row = await _client
        .from('listings')
        .update({'title': title, 'description': description, 'category': category.dbValue, 'location': location, 'price': price})
        .eq('id', id)
        .select()
        .single();
    return Listing.fromMap(row);
  }

  /// FR-13: delete/deactivate is a soft delete (is_active = false), not a row DELETE.
  Future<void> setListingActive(String id, bool isActive) async {
    await _client.from('listings').update({'is_active': isActive}).eq('id', id);
  }

  Future<List<ListingImage>> fetchImages(String listingId) async {
    final rows = await _client.from('listing_images').select().eq('listing_id', listingId).order('sort_order');
    final images = <ListingImage>[];
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      images.add(ListingImage.fromMap(map, publicUrl: await _signedUrl(map['storage_path'] as String)));
    }
    return images;
  }

  Future<ListingImage> uploadImage({
    required String providerId,
    required String listingId,
    required Uint8List bytes,
    required String fileExtension,
    int sortOrder = 0,
  }) async {
    final path = '$providerId/$listingId/${_uniqueFileName(fileExtension)}';
    await _client.storage.from(_imagesBucket).uploadBinary(path, bytes);
    final row = await _client.from('listing_images').insert({'listing_id': listingId, 'storage_path': path, 'sort_order': sortOrder}).select().single();
    return ListingImage.fromMap(row, publicUrl: await _signedUrl(path));
  }

  Future<void> deleteImage(ListingImage image) async {
    await _client.from('listing_images').delete().eq('id', image.id);
    await _client.storage.from(_imagesBucket).remove([image.storagePath]);
  }

  /// The bucket isn't public (see 0005_listing_images_storage.sql) so display URLs
  /// have to be signed rather than the bare getPublicUrl() form.
  Future<String> _signedUrl(String path) {
    return _client.storage.from(_imagesBucket).createSignedUrl(path, 3600);
  }

  String _uniqueFileName(String extension) {
    final suffix = Random().nextInt(1 << 32).toRadixString(36);
    return '${DateTime.now().millisecondsSinceEpoch}_$suffix.$extension';
  }

  Future<List<ListingTimeSlot>> fetchTimeSlots(String listingId) async {
    final rows = await _client.from('listing_time_slots').select().eq('listing_id', listingId).order('day_of_week');
    return (rows as List).map((r) => ListingTimeSlot.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Simplest correct way to save a provider's edited slot list from the form:
  /// replace the whole set rather than diffing individual adds/removes.
  Future<void> replaceTimeSlots(String listingId, List<ListingTimeSlot> slots) async {
    await _client.from('listing_time_slots').delete().eq('listing_id', listingId);
    if (slots.isEmpty) return;
    await _client.from('listing_time_slots').insert(slots.map((s) => s.toInsertMap(listingId)).toList());
  }

  /// FR-40: admin view of every listing regardless of status - relies on the
  /// listings_select_admin RLS policy from G2.
  Future<List<Listing>> fetchAllListings() async {
    final rows = await _client.from('listings').select().order('created_at', ascending: false);
    return (rows as List).map((row) => Listing.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// FR-39.
  Future<void> setListingStatus(String id, ListingStatus status) async {
    await _client.from('listings').update({'status': status.name}).eq('id', id);
  }

  /// FR-41.
  Future<void> setRemovedByAdmin(String id, bool removed) async {
    await _client.from('listings').update({'removed_by_admin': removed}).eq('id', id);
  }
}

final listingRepositoryProvider = Provider<ListingRepository>((ref) {
  return ListingRepository(ref.watch(supabaseClientProvider));
});
