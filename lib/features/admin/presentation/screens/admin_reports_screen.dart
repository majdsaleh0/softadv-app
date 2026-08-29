import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../listings/data/listing_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/domain/profile.dart';
import '../../../reports/application/report_controller.dart';
import '../../../reports/data/report_repository.dart';
import '../../../reports/domain/report.dart';
import '../../../reviews/data/review_repository.dart';

typedef _ReportContext = ({String title, String ownerId, String ownerName});

final _reportContextProvider = FutureProvider.family<_ReportContext, Report>((ref, report) async {
  if (report.targetType == ReportTargetType.listing) {
    final listing = await ref.watch(listingRepositoryProvider).fetchListing(report.targetId);
    final owner = await ref.watch(profileRepositoryProvider).fetchProfile(listing.providerId);
    return (title: listing.title, ownerId: listing.providerId, ownerName: owner.name);
  }
  final review = await ref.watch(reviewRepositoryProvider).fetchReviewById(report.targetId);
  if (review == null) return (title: '(review no longer exists)', ownerId: '', ownerName: '');
  return (title: review.comment?.isNotEmpty == true ? review.comment! : '(no comment)', ownerId: review.customerId, ownerName: review.customerName);
});

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(openReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) return const Center(child: Text('No open reports.'));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(openReportsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final report in reports) _ReportTile(report: report)],
            ),
          );
        },
        error: (error, stackTrace) => Center(child: Text('Could not load reports: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ReportTile extends ConsumerWidget {
  const _ReportTile({required this.report});

  final Report report;

  Future<void> _resolve(BuildContext context, WidgetRef ref, {required String action, required String ownerId}) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action),
        content: TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Resolution note (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (action == 'Remove Content') {
      if (report.targetType == ReportTargetType.listing) {
        await ref.read(listingRepositoryProvider).setRemovedByAdmin(report.targetId, true);
      } else {
        await ref.read(reviewRepositoryProvider).deleteReview(report.targetId);
      }
    } else if (action == 'Ban User' && ownerId.isNotEmpty) {
      await ref.read(profileRepositoryProvider).setProfileStatus(ownerId, AccountStatus.suspended);
    }

    final note = noteController.text.trim();
    await ref.read(reportRepositoryProvider).resolveReport(reportId: report.id, resolution: note.isEmpty ? action : '$action: $note');
    ref.invalidate(openReportsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(_reportContextProvider(report));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${report.targetType == ReportTargetType.listing ? 'Listing' : 'Review'} reported by ${report.reporterName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Reason: ${report.reason}'),
            const SizedBox(height: 4),
            contextAsync.when(
              data: (ctx) => Text('Target: "${ctx.title}" by ${ctx.ownerName}'),
              error: (error, stackTrace) => const Text('Target: could not load'),
              loading: () => const Text('Loading target…'),
            ),
            const SizedBox(height: 8),
            contextAsync.when(
              data: (ctx) => Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: () => _resolve(context, ref, action: 'Remove Content', ownerId: ctx.ownerId), child: const Text('Remove Content')),
                  OutlinedButton(onPressed: () => _resolve(context, ref, action: 'Ban User', ownerId: ctx.ownerId), child: const Text('Ban User')),
                  OutlinedButton(onPressed: () => _resolve(context, ref, action: 'Dismiss', ownerId: ctx.ownerId), child: const Text('Dismiss')),
                ],
              ),
              error: (error, stackTrace) => const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
