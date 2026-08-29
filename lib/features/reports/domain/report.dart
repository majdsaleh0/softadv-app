enum ReportTargetType { listing, review }

extension ReportTargetTypeDb on ReportTargetType {
  String get dbValue => this == ReportTargetType.listing ? 'listing' : 'review';
}

ReportTargetType reportTargetTypeFromDb(String value) => value == 'listing' ? ReportTargetType.listing : ReportTargetType.review;

enum ReportStatus { open, resolved }

ReportStatus reportStatusFromDb(String value) => value == 'resolved' ? ReportStatus.resolved : ReportStatus.open;

class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.resolution,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final String reporterName;
  final ReportTargetType targetType;
  final String targetId;
  final String reason;
  final ReportStatus status;
  final String? resolution;
  final DateTime createdAt;

  factory Report.fromMap(Map<String, dynamic> map) {
    final reporter = map['reporter'] as Map<String, dynamic>?;
    return Report(
      id: map['id'] as String,
      reporterId: map['reporter_id'] as String,
      reporterName: reporter?['name'] as String? ?? '',
      targetType: reportTargetTypeFromDb(map['target_type'] as String),
      targetId: map['target_id'] as String,
      reason: map['reason'] as String,
      status: reportStatusFromDb(map['status'] as String),
      resolution: map['resolution'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
