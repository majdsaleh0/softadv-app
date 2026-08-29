import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../profile/application/profile_controller.dart';
import '../../../profile/domain/profile.dart';
import '../../application/listing_controller.dart';
import '../../data/listing_repository.dart';
import '../../domain/listing.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Listings')),
      floatingActionButton: FloatingActionButton(onPressed: () => context.push(AppRoute.newListing), child: const Icon(Icons.add)),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text('Not signed in.'));
          if (profile.role != UserRole.provider) {
            return const Center(child: Text('Only provider accounts have listings.'));
          }
          return const _ListingsList();
        },
        error: (error, stackTrace) => Center(child: Text('Could not load profile: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ListingsList extends ConsumerWidget {
  const _ListingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsProvider);

    return listingsAsync.when(
      data: (listings) {
        if (listings.isEmpty) {
          return const Center(child: Text('No listings yet. Tap + to create one.'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myListingsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: listings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final listing = listings[index];
              return Card(
                child: ListTile(
                  title: Text(listing.title),
                  subtitle: Text('${listing.category.label} · \$${listing.price.toStringAsFixed(2)}'),
                  onTap: () => context.push(AppRoute.editListingPath(listing.id)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(label: Text(listing.status.name)),
                      IconButton(
                        icon: Icon(listing.isActive ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        tooltip: listing.isActive ? 'Deactivate' : 'Reactivate',
                        onPressed: () async {
                          await ref.read(listingRepositoryProvider).setListingActive(listing.id, !listing.isActive);
                          ref.invalidate(myListingsProvider);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      error: (error, stackTrace) => Center(child: Text('Could not load listings: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
