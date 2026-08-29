import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/report_repository.dart';
import '../../domain/report.dart';

/// FR-44. Shows a reason prompt and submits the report; safe to call from anywhere
/// a listing or review is displayed.
Future<void> showReportDialog(BuildContext context, WidgetRef ref, {required ReportTargetType targetType, required String targetId}) async {
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Report ${targetType == ReportTargetType.listing ? 'listing' : 'review'}'),
      content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Submit')),
      ],
    ),
  );
  if (reason == null || reason.isEmpty) return;
  await ref.read(reportRepositoryProvider).submitReport(targetType: targetType, targetId: targetId, reason: reason);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted.')));
  }
}
