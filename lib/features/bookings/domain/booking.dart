import 'package:flutter/material.dart';

enum BookingStatus { requested, accepted, rejected, completed, cancelled }

BookingStatus bookingStatusFromDb(String value) {
  return BookingStatus.values.firstWhere((s) => s.name == value, orElse: () => BookingStatus.requested);
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

class Booking {
  const Booking({
    required this.id,
    required this.listingId,
    required this.customerId,
    required this.providerId,
    required this.timeSlotId,
    required this.date,
    required this.status,
    required this.createdAt,
    required this.listingTitle,
    required this.customerName,
    required this.providerDisplayName,
    required this.slotDayOfWeek,
    required this.slotStartTime,
    required this.slotEndTime,
    this.rejectReason,
  });

  final String id;
  final String listingId;
  final String customerId;
  final String providerId;
  final String timeSlotId;
  final DateTime date;
  final BookingStatus status;
  final DateTime createdAt;
  final String? rejectReason;

  // Joined display fields - see DiscoveryRepository-style embedded selects in BookingRepository.
  final String listingTitle;
  final String customerName;
  final String providerDisplayName;
  final int slotDayOfWeek;
  final TimeOfDay slotStartTime;
  final TimeOfDay slotEndTime;

  factory Booking.fromMap(Map<String, dynamic> map) {
    final listing = map['listings'] as Map<String, dynamic>?;
    final customer = map['customer'] as Map<String, dynamic>?;
    final provider = map['provider'] as Map<String, dynamic>?;
    final slot = map['slot'] as Map<String, dynamic>?;
    final providerBusinessName = provider?['business_name'] as String?;

    return Booking(
      id: map['id'] as String,
      listingId: map['listing_id'] as String,
      customerId: map['customer_id'] as String,
      providerId: map['provider_id'] as String,
      timeSlotId: map['time_slot_id'] as String,
      date: DateTime.parse(map['date'] as String),
      status: bookingStatusFromDb(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      rejectReason: map['reject_reason'] as String?,
      listingTitle: listing?['title'] as String? ?? '',
      customerName: customer?['name'] as String? ?? '',
      providerDisplayName: (providerBusinessName != null && providerBusinessName.isNotEmpty) ? providerBusinessName : (provider?['name'] as String? ?? ''),
      slotDayOfWeek: slot?['day_of_week'] as int? ?? 0,
      slotStartTime: _parseTime(slot?['start_time'] as String? ?? '00:00:00'),
      slotEndTime: _parseTime(slot?['end_time'] as String? ?? '00:00:00'),
    );
  }
}
