import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/edge_function_error.dart';
import '../../../messaging/domain/message.dart';
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

class IncomingBookingsScreen extends ConsumerWidget {
  const IncomingBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(incomingBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Bookings')),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) return const Center(child: Text('No incoming bookings yet.'));
          final grouped = _groupByStatus(bookings);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(incomingBookingsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final status in _displayOrder)
                  if (grouped[status]?.isNotEmpty ?? false) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_statusLabel(status), style: Theme.of(context).textTheme.titleMedium),
                    ),
                    for (final booking in grouped[status]!) _ProviderBookingTile(booking: booking),
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

class _ProviderBookingTile extends ConsumerWidget {
  const _ProviderBookingTile({required this.booking});

  final Booking booking;

  Future<void> _respond(BuildContext context, WidgetRef ref, {required bool accept}) async {
    String? reason;
    if (!accept) {
      reason = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Reject booking'),
            content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason (optional)')),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Reject')),
            ],
          );
        },
      );
      if (reason == null) return;
    }
    try {
      await ref.read(bookingRepositoryProvider).respondToBooking(bookingId: booking.id, accept: accept, reason: reason?.isEmpty ?? true ? null : reason);
      ref.invalidate(incomingBookingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(edgeFunctionErrorMessage(e))));
      }
    }
  }

  Future<void> _lifecycle(BuildContext context, WidgetRef ref, {required bool complete}) async {
    try {
      final repo = ref.read(bookingRepositoryProvider);
      if (complete) {
        await repo.completeBooking(booking.id);
      } else {
        await repo.cancelBooking(booking.id);
      }
      ref.invalidate(incomingBookingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(edgeFunctionErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(booking.listingTitle),
        subtitle: Text(
          'with ${booking.customerName} · ${booking.date.toLocal().toString().split(' ').first}\n'
          '${booking.slotStartTime.format(context)} - ${booking.slotEndTime.format(context)}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.message_outlined),
              tooltip: 'Message',
              onPressed: () {
                final ConversationRef conversation = (otherPartyId: booking.customerId, otherPartyName: booking.customerName, listingId: null, bookingId: booking.id);
                context.push(AppRoute.messageThread, extra: conversation);
              },
            ),
            ...switch (booking.status) {
              BookingStatus.requested => [
                IconButton(icon: const Icon(Icons.check_circle_outline), tooltip: 'Accept', onPressed: () => _respond(context, ref, accept: true)),
                IconButton(icon: const Icon(Icons.cancel_outlined), tooltip: 'Reject', onPressed: () => _respond(context, ref, accept: false)),
              ],
              BookingStatus.accepted => [
                IconButton(icon: const Icon(Icons.done_all), tooltip: 'Mark completed', onPressed: () => _lifecycle(context, ref, complete: true)),
                IconButton(icon: const Icon(Icons.cancel_outlined), tooltip: 'Cancel', onPressed: () => _lifecycle(context, ref, complete: false)),
              ],
              _ => const <Widget>[],
            },
          ],
        ),
      ),
    );
  }
}
