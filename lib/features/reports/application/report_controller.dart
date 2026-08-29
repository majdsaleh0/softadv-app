import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/report_repository.dart';
import '../domain/report.dart';

final openReportsProvider = FutureProvider<List<Report>>((ref) {
  return ref.watch(reportRepositoryProvider).fetchOpenReports();
});
