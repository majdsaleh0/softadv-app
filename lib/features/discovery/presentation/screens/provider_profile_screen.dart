import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../application/discovery_controller.dart';
import '../widgets/listing_card.dart';

class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(providerProfileProvider(providerId));
    final listingsAsync = ref.watch(providerListingsProvider(providerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Provider Profile')),
      body: profileAsync.when(
        data: (profile) {
          final ratedListings = listingsAsync.value?.where((l) => l.avgRating != null).toList() ?? [];
          final avgRating = ratedListings.isEmpty ? null : ratedListings.map((l) => l.avgRating!).reduce((a, b) => a + b) / ratedListings.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CircleAvatar(radius: 36, child: Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?')),
              const SizedBox(height: 12),
              Text(profile.businessName?.isNotEmpty == true ? profile.businessName! : profile.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              avgRating != null
                  ? Row(
                      children: [
                        const Icon(Icons.star, size: 18, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text('${avgRating.toStringAsFixed(1)} avg rating'),
                      ],
                    )
                  : const Text('No ratings yet'),
              const SizedBox(height: 24),
              Text('Active Listings', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              listingsAsync.when(
                data: (listings) {
                  if (listings.isEmpty) return const Text('No active listings.');
                  return Column(
                    children: [for (final listing in listings) ListingCard(listing: listing, onTap: () => context.push(AppRoute.listingDetailPath(listing.id)))],
                  );
                },
                error: (error, stackTrace) => Text('Could not load listings: $error'),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load provider: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
