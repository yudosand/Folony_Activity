import '../enums/app_role.dart';
import 'approval_step.dart';

enum ApprovalModule {
  leave,
  wfa,
  attendance,
  network;
}

class ApprovalItem {
  const ApprovalItem({
    required this.id,
    required this.module,
    required this.referenceId,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.title,
    required this.summary,
    required this.status,
    required this.submittedAt,
    required this.approvalSteps,
  });

  final String id;
  final ApprovalModule module;
  final String referenceId;
  final String requesterId;
  final String requesterName;
  final AppRole requesterRole;
  final String title;
  final String summary;
  final ApprovalStepStatus status;
  final DateTime submittedAt;
  final List<ApprovalStep> approvalSteps;

  factory ApprovalItem.fromJson(Map<String, dynamic> json) {
    return ApprovalItem(
      id: json['id'] as String? ?? '',
      module: ApprovalModule.values.firstWhere(
        (item) => item.name == json['module'],
        orElse: () => ApprovalModule.leave,
      ),
      referenceId: json['reference_id'] as String? ?? '',
      requesterId: json['requester_id'] as String? ?? '',
      requesterName: json['requester_name'] as String? ?? '',
      requesterRole: AppRole.values.firstWhere(
        (role) => role.name == json['requester_role'],
        orElse: () => AppRole.staff,
      ),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      status: ApprovalStepStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => ApprovalStepStatus.pending,
      ),
      submittedAt: _dateTimeFromJson(json['submitted_at']),
      approvalSteps: _approvalStepsFromJson(json['approval_steps']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'module': module.name,
      'reference_id': referenceId,
      'requester_id': requesterId,
      'requester_name': requesterName,
      'requester_role': requesterRole.name,
      'title': title,
      'summary': summary,
      'status': status.name,
      'submitted_at': submittedAt.toIso8601String(),
      'approval_steps': approvalSteps.map((item) => item.toJson()).toList(),
    };
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
