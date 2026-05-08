import '../enums/app_role.dart';
import 'approval_step.dart';
import 'remote_attachment.dart';

enum WfaRequestMode {
  regular,
  overtime;
}

enum WfaCompensationMode {
  normalShift,
  shiftMundur,
  klaimLembur,
  reviewHr;
}

class WfaTaskUpdateRecord {
  const WfaTaskUpdateRecord({
    required this.id,
    required this.message,
    required this.createdAt,
    this.actorId,
    this.attachments = const [],
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final String? actorId;
  final List<RemoteAttachment> attachments;

  factory WfaTaskUpdateRecord.fromJson(Map<String, dynamic> json) {
    return WfaTaskUpdateRecord(
      id: json['id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: _dateTimeFromJson(json['created_at']),
      actorId: json['actor_id'] as String?,
      attachments: _attachmentsFromJson(json['attachments']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'actor_id': actorId,
      'attachments': attachments.map((item) => item.toJson()).toList(),
    };
  }
}

class WfaRequestRecord {
  const WfaRequestRecord({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.mode,
    required this.compensationMode,
    required this.workDate,
    required this.startTime,
    required this.endTime,
    required this.locationLabel,
    required this.reason,
    required this.initialTask,
    required this.status,
    required this.approvalSteps,
    required this.taskUpdates,
    required this.submittedAt,
    this.actualStartAt,
    this.actualEndAt,
    this.note,
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final AppRole requesterRole;
  final WfaRequestMode mode;
  final WfaCompensationMode compensationMode;
  final DateTime workDate;
  final String startTime;
  final String endTime;
  final String locationLabel;
  final String reason;
  final String initialTask;
  final WorkflowStatus status;
  final List<ApprovalStep> approvalSteps;
  final List<WfaTaskUpdateRecord> taskUpdates;
  final DateTime submittedAt;
  final DateTime? actualStartAt;
  final DateTime? actualEndAt;
  final String? note;

  factory WfaRequestRecord.fromJson(Map<String, dynamic> json) {
    return WfaRequestRecord(
      id: json['id'] as String? ?? '',
      requesterId: json['requester_id'] as String? ?? '',
      requesterName: json['requester_name'] as String? ?? '',
      requesterRole: AppRole.values.firstWhere(
        (role) => role.name == json['requester_role'],
        orElse: () => AppRole.staff,
      ),
      mode: WfaRequestMode.values.firstWhere(
        (item) => item.name == json['mode'],
        orElse: () => WfaRequestMode.regular,
      ),
      compensationMode: WfaCompensationMode.values.firstWhere(
        (item) => item.name == json['compensation_mode'],
        orElse: () => WfaCompensationMode.normalShift,
      ),
      workDate: _dateTimeFromJson(json['work_date']),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      locationLabel: json['location_label'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      initialTask: json['initial_task'] as String? ?? '',
      status: WorkflowStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => WorkflowStatus.pending,
      ),
      approvalSteps: _approvalStepsFromJson(json['approval_steps']),
      taskUpdates: _taskUpdatesFromJson(json['task_updates']),
      submittedAt: _dateTimeFromJson(json['submitted_at']),
      actualStartAt: _nullableDateTimeFromJson(json['actual_start_at']),
      actualEndAt: _nullableDateTimeFromJson(json['actual_end_at']),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'requester_name': requesterName,
      'requester_role': requesterRole.name,
      'mode': mode.name,
      'compensation_mode': compensationMode.name,
      'work_date': workDate.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'location_label': locationLabel,
      'reason': reason,
      'initial_task': initialTask,
      'status': status.name,
      'approval_steps': approvalSteps.map((item) => item.toJson()).toList(),
      'task_updates': taskUpdates.map((item) => item.toJson()).toList(),
      'submitted_at': submittedAt.toIso8601String(),
      'actual_start_at': actualStartAt?.toIso8601String(),
      'actual_end_at': actualEndAt?.toIso8601String(),
      'note': note,
    };
  }

  WfaRequestRecord copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    AppRole? requesterRole,
    WfaRequestMode? mode,
    WfaCompensationMode? compensationMode,
    DateTime? workDate,
    String? startTime,
    String? endTime,
    String? locationLabel,
    String? reason,
    String? initialTask,
    WorkflowStatus? status,
    List<ApprovalStep>? approvalSteps,
    List<WfaTaskUpdateRecord>? taskUpdates,
    DateTime? submittedAt,
    DateTime? actualStartAt,
    DateTime? actualEndAt,
    String? note,
  }) {
    return WfaRequestRecord(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterRole: requesterRole ?? this.requesterRole,
      mode: mode ?? this.mode,
      compensationMode: compensationMode ?? this.compensationMode,
      workDate: workDate ?? this.workDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      locationLabel: locationLabel ?? this.locationLabel,
      reason: reason ?? this.reason,
      initialTask: initialTask ?? this.initialTask,
      status: status ?? this.status,
      approvalSteps: approvalSteps ?? this.approvalSteps,
      taskUpdates: taskUpdates ?? this.taskUpdates,
      submittedAt: submittedAt ?? this.submittedAt,
      actualStartAt: actualStartAt ?? this.actualStartAt,
      actualEndAt: actualEndAt ?? this.actualEndAt,
      note: note ?? this.note,
    );
  }
}

enum WorkflowStatus {
  draft,
  pending,
  approved,
  rejected,
  cancelled,
  active,
  completed;
}

DateTime _dateTimeFromJson(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _nullableDateTimeFromJson(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
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

List<WfaTaskUpdateRecord> _taskUpdatesFromJson(Object? value) {
  if (value is List) {
    return value
        .whereType<Map<String, dynamic>>()
        .map(WfaTaskUpdateRecord.fromJson)
        .toList();
  }
  return const [];
}

List<RemoteAttachment> _attachmentsFromJson(Object? value) {
  if (value is List) {
    return value
        .whereType<Map<String, dynamic>>()
        .map(RemoteAttachment.fromJson)
        .toList();
  }
  return const [];
}
