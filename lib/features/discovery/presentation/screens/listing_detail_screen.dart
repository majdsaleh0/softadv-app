import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../listings/data/listing_repository.dart';
import '../../../listings/domain/listing.dart';
import '../../../profile/application/profile_controller.dart';
import '../../../profile/domain/profile.dart';
import '../../../messaging/domain/message.dart';
import '../../../reports/domain/report.dart';
import '../../../reports/presentation/widgets/report_dialog.dart';
import '../../../reviews/application/review_controller.dart';
import '../../../reviews/data/review_repository.dart';
import '../../../reviews/domain/review.dart';
import '../../application/discovery_controller.dart';

class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingDetailProvider(listingId));
    final profileAsync = ref.watch(currentProfileProvider);
    final isCustomer = profileAsync.value?.role == UserRole.customer;
    final myProfileId = profileAsync.value?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Report listing',
            onPressed: () => showReportDialog(context, ref, targetType: ReportTargetType.listing, targetId: listingId),
          ),
        ],
      ),
      body: listingAsync.when(
        data: (listing) {
          final imagesAsync = ref.watch(_listingImagesProvider(listingId));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imagesAsync.when(
                  data: (images) {
                    if (images.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) =>
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(images[index].publicUrl, width: 240, fit: BoxFit.cover)),
                      ),
                    );
                  },
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                ),
                const SizedBox(height: 16),
                Text(listing.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(listing.category.label)),
                    if (listing.avgRating != null)
                      Chip(avatar: const Icon(Icons.star, size: 16, color: Colors.amber), label: Text('${listing.avgRating!.toStringAsFixed(1)} (${listing.reviewCount})'))
                    else
                      const Chip(label: Text('No ratings yet')),
                  ],
                ),
                const SizedBox(height: 16),
                Text('\$${listing.price.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Text(listing.description),
                const SizedBox(height: 16),
                Row(children: [const Icon(Icons.location_on_outlined, size: 18), const SizedBox(width: 4), Text(listing.location)]),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.push(AppRoute.providerProfilePath(listing.providerId)),
                  child: const Text('View Provider Profile'),
                ),
                if (isCustomer) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push(AppRoute.requestBookingPath(listing.id)),
                    child: const Text('Request Booking'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      final providerProfile = ref.read(providerProfileProvider(listing.providerId)).value;
                      final ConversationRef conversation = (
                        otherPartyId: listing.providerId,
                        otherPartyName: providerProfile?.businessName?.isNotEmpty == true ? providerProfile!.businessName! : (providerProfile?.name ?? ''),
                        listingId: listing.id,
                        bookingId: null,
                      );
                      context.push(AppRoute.messageThread, extra: conversation);
                    },
                    child: const Text('Message Provider'),
                  ),
                ],
                const SizedBox(height: 24),
                Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _ReviewsList(listingId: listing.id, isOwningProvider: myProfileId == listing.providerId, myProfileId: myProfileId),
              ],
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load listing: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

final _listingImagesProvider = FutureProvider.family((ref, String listingId) {
  return ref.watch(listingRepositoryProvider).fetchImages(listingId);
});

class _ReviewsList extends ConsumerWidget {
  const _ReviewsList({required this.listingId, required this.isOwningProvider, required this.myProfileId});

  final String listingId;
  final bool isOwningProvider;
  final String? myProfileId;

  Future<void> _reply(BuildContext context, WidgetRef ref, Review review) async {
    final controller = TextEditingController(text: review.providerReply ?? '');
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply to review'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Your reply')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (reply == null || reply.isEmpty) return;
    await ref.read(reviewRepositoryProvider).replyToReview(reviewId: review.id, reply: reply);
    ref.invalidate(listingReviewsProvider(listingId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(listingReviewsProvider(listingId));

    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) return const Text('No reviews yet.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final review in reviews)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(review.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          Text(' ${review.rating}/5'),
                        ],
                      ),
                      if (review.comment != null && review.comment!.isNotEmpty) ...[const SizedBox(height: 4), Text(review.comment!)],
                      if (review.providerReply != null && review.providerReply!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                          child: Text('Provider reply: ${review.providerReply}'),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOwningProvider)
                              TextButton(
                                onPressed: () => _reply(context, ref, review),
                                child: Text(review.providerReply == null || review.providerReply!.isEmpty ? 'Reply' : 'Edit reply'),
                              ),
                            if (myProfileId != null && myProfileId != review.customerId)
                              TextButton(
                                onPressed: () => showReportDialog(context, ref, targetType: ReportTargetType.review, targetId: review.id),
                                child: const Text('Report'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      error: (error, stackTrace) => Text('Could not load reviews: $error'),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
