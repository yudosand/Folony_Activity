import '../enums/app_role.dart';
import 'approval_step.dart';
import 'remote_attachment.dart';

enum LeaveCategory {
  cuti,
  sakit,
  izinPerJam,
  izinPerHari;
}

enum LeaveCompensationOption {
  potongSaldoCuti,
  potongGaji,
  tidakPotongGaji;
}

enum WorkflowStatus {
  draft,
  pending,
  approved,
  rejected,
  cancelled,
  completed;
}

class LeaveRequestRecord {
  const LeaveRequestRecord({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.category,
    required this.compensationOption,
    required this.startAt,
    required this.endAt,
    required this.durationValue,
    required this.reason,
    required this.delegateTo,
    required this.status,
    required this.approvalSteps,
    required this.submittedAt,
    this.attachments = const [],
    this.note,
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final AppRole requesterRole;
  final LeaveCategory category;
  final LeaveCompensationOption compensationOption;
  final DateTime startAt;
  final DateTime endAt;
  final double durationValue;
  final String reason;
  final String delegateTo;
  final WorkflowStatus status;
  final List<ApprovalStep> approvalSteps;
  final DateTime submittedAt;
  final List<RemoteAttachment> attachments;
  final String? note;

  factory LeaveRequestRecord.fromJson(Map<String, dynamic> json) {
    return LeaveRequestRecord(
      id: json['id'] as String? ?? '',
      requesterId: json['requester_id'] as String? ?? '',
      requesterName: json['requester_name'] as String? ?? '',
      requesterRole: AppRole.values.firstWhere(
        (role) => role.name == json['requester_role'],
        orElse: () => AppRole.staff,
      ),
      category: LeaveCategory.values.firstWhere(
        (item) => item.name == json['category'],
        orElse: () => LeaveCategory.cuti,
      ),
      compensationOption: LeaveCompensationOption.values.firstWhere(
        (item) => item.name == json['compensation_option'],
        orElse: () => LeaveCompensationOption.potongSaldoCuti,
      ),
      startAt: _dateTimeFromJson(json['start_at']),
      endAt: _dateTimeFromJson(json['end_at']),
      durationValue: (json['duration_value'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      delegateTo: json['delegate_to'] as String? ?? '',
      status: WorkflowStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => WorkflowStatus.pending,
      ),
      approvalSteps: _approvalStepsFromJson(json['approval_steps']),
      submittedAt: _dateTimeFromJson(json['submitted_at']),
      attachments: _attachmentsFromJson(json['attachments']),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'requester_name': requesterName,
      'requester_role': requesterRole.name,
      'category': category.name,
      'compensation_option': compensationOption.name,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'duration_value': durationValue,
      'reason': reason,
      'delegate_to': delegateTo,
      'status': status.name,
      'approval_steps': approvalSteps.map((item) => item.toJson()).toList(),
      'submitted_at': submittedAt.toIso8601String(),
      'attachments': attachments.map((item) => item.toJson()).toList(),
      'note': note,
    };
  }

  LeaveRequestRecord copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    AppRole? requesterRole,
    LeaveCategory? category,
    LeaveCompensationOption? compensationOption,
    DateTime? startAt,
    DateTime? endAt,
    double? durationValue,
    String? reason,
    String? delegateTo,
    WorkflowStatus? status,
    List<ApprovalStep>? approvalSteps,
    DateTime? submittedAt,
    List<RemoteAttachment>? attachments,
    String? note,
  }) {
    return LeaveRequestRecord(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterRole: requesterRole ?? this.requesterRole,
      category: category ?? this.category,
      compensationOption: compensationOption ?? this.compensationOption,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      durationValue: durationValue ?? this.durationValue,
      reason: reason ?? this.reason,
      delegateTo: delegateTo ?? this.delegateTo,
      status: status ?? this.status,
      approvalSteps: approvalSteps ?? this.approvalSteps,
      submittedAt: submittedAt ?? this.submittedAt,
      attachments: attachments ?? this.attachments,
      note: note ?? this.note,
    );
  }
}

DateTime _dateTimeFromJson(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

List<ApprovalStep> _approvalStepsFromJson(Object? value) {
  if (value is List) {
    return value
        .whereType<Map<String, dynamic>>()
        .map(ApprovalStep.fromJson)
        .toList();
  }
  return const [];
}

List<RemoteAttachment> _attachmentsFromJson(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => RemoteAttachment.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
  return const [];
}
