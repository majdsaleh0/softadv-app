import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/edge_function_error.dart';
import '../../../messaging/domain/message.dart';
import '../../../reviews/application/review_controller.dart';
import '../../../reviews/data/review_repository.dart';
import '../../application/booking_controller.dart';
import '../../data/booking_repository.dart';
import '../../domain/booking.dart';

const _displayOrder = [BookingStatus.requested, BookingStatus.accepted, BookingStatus.completed, BookingStatus.rejected, BookingStatus.cancelled];

String _statusLabel(BookingStatus status) => switch (status) {
  BookingStatus.requested => 'Requested',
  BookingStatus.accepted => 'Accepted',
  BookingStatus.completed => 'Completed',
  BookingStatus.rejected => 'Rejected',
  BookingStatus.cancelled => 'Cancelled',
};

Map<BookingStatus, List<Booking>> _groupByStatus(List<Booking> bookings) {
  final grouped = <BookingStatus, List<Booking>>{};
  for (final booking in bookings) {
    (grouped[booking.status] ??= []).add(booking);
  }
  return grouped;
}

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) return const Center(child: Text('No bookings yet.'));
          final grouped = _groupByStatus(bookings);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myBookingsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final status in _displayOrder)
                  if (grouped[status]?.isNotEmpty ?? false) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_statusLabel(status), style: Theme.of(context).textTheme.titleMedium),
                    ),
                    for (final booking in grouped[status]!) _CustomerBookingTile(booking: booking),
                  ],
              ],
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load bookings: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _CustomerBookingTile extends ConsumerWidget {
  const _CustomerBookingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCancel = booking.status == BookingStatus.requested || booking.status == BookingStatus.accepted;

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(booking.listingTitle),
            subtitle: Text(
              'with ${booking.providerDisplayName} · ${booking.date.toLocal().toString().split(' ').first}\n'
              '${booking.slotStartTime.format(context)} - ${booking.slotEndTime.format(context)}'
              '${booking.status == BookingStatus.rejected && (booking.rejectReason?.isNotEmpty ?? false) ? '\nReason: ${booking.rejectReason}' : ''}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.message_outlined),
                  tooltip: 'Message',
                  onPressed: () {
                    final ConversationRef conversation = (otherPartyId: booking.providerId, otherPartyName: booking.providerDisplayName, listingId: null, bookingId: booking.id);
                    context.push(AppRoute.messageThread, extra: conversation);
                  },
                ),
                if (canCancel)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined),
                    tooltip: 'Cancel',
                    onPressed: () async {
                      try {
                        await ref.read(bookingRepositoryProvider).cancelBooking(booking.id);
                        ref.invalidate(myBookingsProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(edgeFunctionErrorMessage(e))));
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
          if (booking.status == BookingStatus.completed) _ReviewSection(booking: booking),
        ],
      ),
    );
  }
}

class _ReviewSection extends ConsumerWidget {
  const _ReviewSection({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(bookingReviewProvider(booking.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: reviewAsync.when(
          data: (review) {
            if (review == null) {
              return FilledButton.tonal(
                onPressed: () => context.push(AppRoute.reviewFormPath(booking.id)),
                child: const Text('Leave a Review'),
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                Text(' ${review.rating}/5'),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => context.push(AppRoute.reviewFormPath(booking.id), extra: review),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(reviewRepositoryProvider).deleteReview(review.id);
                    ref.invalidate(bookingReviewProvider(booking.id));
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
          error: (error, stackTrace) => const SizedBox.shrink(),
          loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ),
    );
  }
}
