import 'package:flutter/material.dart';

const weekdayLabels = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

class ListingTimeSlot {
  const ListingTimeSlot({this.id, required this.dayOfWeek, required this.startTime, required this.endTime});

  /// Null for a slot the provider has added locally but not yet saved.
  final String? id;
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  factory ListingTimeSlot.fromMap(Map<String, dynamic> map) {
    return ListingTimeSlot(
      id: map['id'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startTime: _parseTime(map['start_time'] as String),
      endTime: _parseTime(map['end_time'] as String),
    );
  }

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  Map<String, dynamic> toInsertMap(String listingId) => {
    'listing_id': listingId,
    'day_of_week': dayOfWeek,
    'start_time': _formatTime(startTime),
    'end_time': _formatTime(endTime),
  };
}
