import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/booking.dart';

class BookingRepository {
  BookingRepository(this._client);

  final SupabaseClient _client;

  static const _selectWithDetails = '''
    *,
    listings(title),
    customer:profiles!bookings_customer_id_fkey(name),
    provider:profiles!bookings_provider_id_fkey(name, business_name),
    slot:listing_time_slots(day_of_week, start_time, end_time)
  ''';

  Future<List<Booking>> fetchMyBookings(String customerId) async {
    final rows = await _client.from('bookings').select(_selectWithDetails).eq('customer_id', customerId).order('date', ascending: false);
    return (rows as List).map((r) => Booking.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<Booking>> fetchIncomingBookings(String providerId) async {
    final rows = await _client.from('bookings').select(_selectWithDetails).eq('provider_id', providerId).order('date', ascending: false);
    return (rows as List).map((r) => Booking.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// FR-22. Slot-availability and role checks happen server-side in the Edge Function.
  Future<void> createBooking({required String listingId, required DateTime date, required String timeSlotId}) async {
    await _client.functions.invoke(
      'create-booking',
      body: {'listing_id': listingId, 'date': _formatDate(date), 'time_slot_id': timeSlotId},
    );
  }

  /// FR-25/26.
  Future<void> respondToBooking({required String bookingId, required bool accept, String? reason}) async {
    await _client.functions.invoke(
      'respond-to-booking',
      body: {'booking_id': bookingId, 'action': accept ? 'accept' : 'reject', 'reason': ?reason},
    );
  }

  /// FR-27.
  Future<void> cancelBooking(String bookingId) async {
    await _client.functions.invoke('booking-lifecycle', body: {'booking_id': bookingId, 'action': 'cancel'});
  }

  /// FR-28.
  Future<void> completeBooking(String bookingId) async {
    await _client.functions.invoke('booking-lifecycle', body: {'booking_id': bookingId, 'action': 'complete'});
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(supabaseClientProvider));
});
