import '../enums/app_role.dart';

enum ApprovalStepStatus {
  pending,
  approved,
  rejected,
  skipped;
}

extension ApprovalStepStatusX on ApprovalStepStatus {
  String get label {
    switch (this) {
      case ApprovalStepStatus.pending:
        return 'Pending';
      case ApprovalStepStatus.approved:
        return 'Disetujui';
      case ApprovalStepStatus.rejected:
        return 'Ditolak';
      case ApprovalStepStatus.skipped:
        return 'Dilewati';
    }
  }
}

class ApprovalStep {
  const ApprovalStep({
    required this.sequence,
    required this.approverRole,
    required this.status,
    this.approverId,
    this.approverName,
    this.note,
    this.actedAt,
  });

  final int sequence;
  final AppRole approverRole;
  final ApprovalStepStatus status;
  final String? approverId;
  final String? approverName;
  final String? note;
  final DateTime? actedAt;

  factory ApprovalStep.fromJson(Map<String, dynamic> json) {
    return ApprovalStep(
      sequence: json['sequence'] as int? ?? 0,
      approverRole: _appRoleFromName(json['approver_role'] as String?),
      status: _statusFromName(json['status'] as String?),
      approverId: json['approver_id'] as String?,
      approverName: json['approver_name'] as String?,
      note: json['note'] as String?,
      actedAt: _dateTimeFromJson(json['acted_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sequence': sequence,
      'approver_role': approverRole.name,
      'status': status.name,
      'approver_id': approverId,
      'approver_name': approverName,
      'note': note,
      'acted_at': actedAt?.toIso8601String(),
    };
  }

  ApprovalStep copyWith({
    int? sequence,
    AppRole? approverRole,
    ApprovalStepStatus? status,
    String? approverId,
    String? approverName,
    String? note,
    DateTime? actedAt,
  }) {
    return ApprovalStep(
      sequence: sequence ?? this.sequence,
      approverRole: approverRole ?? this.approverRole,
      status: status ?? this.status,
      approverId: approverId ?? this.approverId,
      approverName: approverName ?? this.approverName,
      note: note ?? this.note,
      actedAt: actedAt ?? this.actedAt,
    );
  }

  static AppRole _appRoleFromName(String? value) {
    return AppRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => AppRole.staff,
    );
  }

  static ApprovalStepStatus _statusFromName(String? value) {
    return ApprovalStepStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ApprovalStepStatus.pending,
    );
  }

  static DateTime? _dateTimeFromJson(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
