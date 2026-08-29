import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/edge_function_error.dart';
import '../../../listings/data/listing_repository.dart';
import '../../../listings/domain/listing_time_slot.dart';
import '../../data/booking_repository.dart';

class RequestBookingScreen extends ConsumerStatefulWidget {
  const RequestBookingScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<RequestBookingScreen> createState() => _RequestBookingScreenState();
}

class _RequestBookingScreenState extends ConsumerState<RequestBookingScreen> {
  ListingTimeSlot? _selectedSlot;
  DateTime? _selectedDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  DateTime _nextDateForWeekday(DateTime from, int targetDow) {
    var date = DateTime(from.year, from.month, from.day);
    while (date.weekday % 7 != targetDow) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  Future<void> _pickDate() async {
    final slot = _selectedSlot;
    if (slot == null) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDateForWeekday(now, slot.dayOfWeek),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (date) => date.weekday % 7 == slot.dayOfWeek,
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    final slot = _selectedSlot;
    final date = _selectedDate;
    if (slot == null || date == null) {
      setState(() => _errorMessage = 'Choose a time slot and date first.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(bookingRepositoryProvider).createBooking(listingId: widget.listingId, date: date, timeSlotId: slot.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking requested.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _errorMessage = edgeFunctionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(_timeSlotsProvider(widget.listingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Request Booking')),
      body: slotsAsync.when(
        data: (slots) {
          if (slots.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This provider has not listed any availability yet.')));
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Choose a time slot', style: Theme.of(context).textTheme.titleMedium),
                    RadioGroup<ListingTimeSlot>(
                      groupValue: _selectedSlot,
                      onChanged: (value) => setState(() {
                        _selectedSlot = value;
                        _selectedDate = null;
                      }),
                      child: Column(
                        children: [
                          for (final slot in slots)
                            RadioListTile<ListingTimeSlot>(
                              value: slot,
                              title: Text('${weekdayLabels[slot.dayOfWeek]}  ${slot.startTime.format(context)} - ${slot.endTime.format(context)}'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _selectedSlot == null ? null : _pickDate,
                      child: Text(_selectedDate == null ? 'Choose a date' : _selectedDate!.toLocal().toString().split(' ').first),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Request Booking'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load availability: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

final _timeSlotsProvider = FutureProvider.family((ref, String listingId) {
  return ref.watch(listingRepositoryProvider).fetchTimeSlots(listingId);
});
