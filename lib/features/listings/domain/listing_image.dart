class ListingImage {
  const ListingImage({
    required this.id,
    required this.listingId,
    required this.storagePath,
    required this.sortOrder,
    required this.publicUrl,
  });

  final String id;
  final String listingId;
  final String storagePath;
  final int sortOrder;

  /// Resolved client-side from [storagePath] via Supabase Storage's public-URL
  /// helper; access is still enforced by the storage.objects RLS policies
  /// regardless of this URL being "public" in shape.
  final String publicUrl;

  factory ListingImage.fromMap(Map<String, dynamic> map, {required String publicUrl}) {
    return ListingImage(
      id: map['id'] as String,
      listingId: map['listing_id'] as String,
      storagePath: map['storage_path'] as String,
      sortOrder: map['sort_order'] as int,
      publicUrl: publicUrl,
    );
  }
}
