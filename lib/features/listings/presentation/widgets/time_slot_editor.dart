import 'package:flutter/material.dart';

import '../../domain/listing_time_slot.dart';

class TimeSlotEditor extends StatelessWidget {
  const TimeSlotEditor({super.key, required this.slots, required this.onAdd, required this.onRemove});

  final List<ListingTimeSlot> slots;
  final ValueChanged<ListingTimeSlot> onAdd;
  final ValueChanged<int> onRemove;

  Future<void> _addSlot(BuildContext context) async {
    final result = await showDialog<ListingTimeSlot>(context: context, builder: (context) => _AddSlotDialog());
    if (result != null) onAdd(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slots.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${weekdayLabels[slots[i].dayOfWeek]}  ${slots[i].startTime.format(context)} - ${slots[i].endTime.format(context)}'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => onRemove(i)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => _addSlot(context), icon: const Icon(Icons.add), label: const Text('Add time slot')),
        ),
      ],
    );
  }
}

class _AddSlotDialog extends StatefulWidget {
  @override
  State<_AddSlotDialog> createState() => _AddSlotDialogState();
}

class _AddSlotDialogState extends State<_AddSlotDialog> {
  int _dayOfWeek = 1;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  String? _error;

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add availability'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _dayOfWeek,
            decoration: const InputDecoration(labelText: 'Day'),
            items: [for (var i = 0; i < weekdayLabels.length; i++) DropdownMenuItem(value: i, child: Text(weekdayLabels[i]))],
            onChanged: (v) => setState(() => _dayOfWeek = v ?? _dayOfWeek),
          ),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Start time'), trailing: Text(_start.format(context)), onTap: () => _pickTime(isStart: true)),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('End time'), trailing: Text(_end.format(context)), onTap: () => _pickTime(isStart: false)),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final startMinutes = _start.hour * 60 + _start.minute;
            final endMinutes = _end.hour * 60 + _end.minute;
            if (endMinutes <= startMinutes) {
              setState(() => _error = 'End time must be after start time');
              return;
            }
            Navigator.of(context).pop(ListingTimeSlot(dayOfWeek: _dayOfWeek, startTime: _start, endTime: _end));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
