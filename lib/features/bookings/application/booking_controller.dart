import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';

final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(bookingRepositoryProvider).fetchMyBookings(user.id);
});

final incomingBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(bookingRepositoryProvider).fetchIncomingBookings(user.id);
});
