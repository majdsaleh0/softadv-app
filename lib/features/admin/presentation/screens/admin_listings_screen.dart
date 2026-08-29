import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../listings/data/listing_repository.dart';
import '../../../listings/domain/listing.dart';
import '../../application/admin_controller.dart';

class AdminListingsScreen extends ConsumerWidget {
  const AdminListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(allListingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Listings')),
      body: listingsAsync.when(
        data: (listings) {
          if (listings.isEmpty) return const Center(child: Text('No listings.'));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allListingsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: listings.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _AdminListingTile(listing: listings[index]),
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load listings: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AdminListingTile extends ConsumerWidget {
  const _AdminListingTile({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = [if (listing.removedByAdmin) 'removed', if (!listing.isActive) 'inactive'].join(', ');

    return Card(
      child: ListTile(
        title: Text(listing.title),
        subtitle: Text('${listing.category.label} · \$${listing.price.toStringAsFixed(2)}${flags.isEmpty ? '' : ' · $flags'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(listing.status.name)),
            if (listing.status == ListingStatus.pending) ...[
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Approve',
                onPressed: () async {
                  await ref.read(listingRepositoryProvider).setListingStatus(listing.id, ListingStatus.approved);
                  ref.invalidate(allListingsProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined),
                tooltip: 'Reject',
                onPressed: () async {
                  await ref.read(listingRepositoryProvider).setListingStatus(listing.id, ListingStatus.rejected);
                  ref.invalidate(allListingsProvider);
                },
              ),
            ],
            if (listing.status == ListingStatus.approved)
              IconButton(
                icon: Icon(listing.removedByAdmin ? Icons.restore : Icons.delete_forever_outlined),
                tooltip: listing.removedByAdmin ? 'Restore' : 'Remove',
                onPressed: () async {
                  await ref.read(listingRepositoryProvider).setRemovedByAdmin(listing.id, !listing.removedByAdmin);
                  ref.invalidate(allListingsProvider);
                },
              ),
          ],
        ),
      ),
    );
  }
}
