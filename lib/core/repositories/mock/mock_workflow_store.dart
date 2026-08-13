import '../../models/approval_item.dart';
import '../../models/approval_step.dart';
import '../../models/leave_request_record.dart' as leave_model;
import '../../models/wfa_request_record.dart' as wfa_model;

class MockWorkflowStore {
  MockWorkflowStore._();

  static final MockWorkflowStore instance = MockWorkflowStore._();

  final Map<String, leave_model.LeaveRequestRecord> _leaveById = {};
  final Map<String, wfa_model.WfaRequestRecord> _wfaById = {};

  List<leave_model.LeaveRequestRecord> listLeaveByUser(String userId) {
    final items = _leaveById.values
        .where((item) => item.requesterId == userId)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  List<leave_model.LeaveRequestRecord> listLeaveForApprover(String approverId) {
    final items = _leaveById.values
        .where((item) => _isPendingForApprover(item.approvalSteps, approverId))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  leave_model.LeaveRequestRecord upsertLeave(
      leave_model.LeaveRequestRecord request) {
    _leaveById[request.id] = request;
    return request;
  }

  leave_model.LeaveRequestRecord updateLeaveStatus({
    required String requestId,
    required leave_model.WorkflowStatus status,
    String? note,
  }) {
    final current = _leaveById[requestId];
    if (current == null) {
      throw StateError('Leave request with id $requestId not found');
    }

    final updated =
        current.copyWith(status: status, note: note ?? current.note);
    _leaveById[requestId] = updated;
    return updated;
  }

  List<wfa_model.WfaRequestRecord> listWfaByUser(String userId) {
    final items = _wfaById.values
        .where((item) => item.requesterId == userId)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  List<wfa_model.WfaRequestRecord> listWfaForApprover(String approverId) {
    final items = _wfaById.values
        .where((item) => _isPendingForApprover(item.approvalSteps, approverId))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return items;
  }

  wfa_model.WfaRequestRecord upsertWfa(wfa_model.WfaRequestRecord request) {
    _wfaById[request.id] = request;
    return request;
  }

  wfa_model.WfaRequestRecord updateWfaStatus({
    required String requestId,
    required wfa_model.WorkflowStatus status,
    String? note,
    DateTime? actualStartAt,
    DateTime? actualEndAt,
    List<wfa_model.WfaTaskUpdateRecord>? taskUpdates,
  }) {
    final current = _wfaById[requestId];
    if (current == null) {
      throw StateError('WFA request with id $requestId not found');
    }

    final updated = current.copyWith(
      status: status,
      note: note ?? current.note,
      actualStartAt: actualStartAt ?? current.actualStartAt,
      actualEndAt: actualEndAt ?? current.actualEndAt,
      taskUpdates: taskUpdates ?? current.taskUpdates,
    );
    _wfaById[requestId] = updated;
    return updated;
  }

  wfa_model.WfaRequestRecord appendWfaTaskUpdate({
    required String requestId,
    required wfa_model.WfaTaskUpdateRecord update,
  }) {
    final current = _wfaById[requestId];
    if (current == null) {
      throw StateError('WFA request with id $requestId not found');
    }

    final updated = current.copyWith(
      taskUpdates: [update, ...current.taskUpdates],
    );
    _wfaById[requestId] = updated;
    return updated;
  }

  List<ApprovalItem> listApprovalInbox({
    required String approverId,
    ApprovalModule? module,
  }) {
    final items = <ApprovalItem>[
      ..._leaveById.values
          .where(
              (item) => _isPendingForApprover(item.approvalSteps, approverId))
          .map(_leaveToApprovalItem),
      ..._wfaById.values
          .where(
              (item) => _isPendingForApprover(item.approvalSteps, approverId))
          .map(_wfaToApprovalItem),
    ];

    final filtered = module == null
        ? items
        : items.where((item) => item.module == module).toList();
    filtered.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return filtered;
  }

  ApprovalItem updateApprovalStatus({
    required String approvalId,
    required String approverId,
    required String approverName,
    required ApprovalStepStatus status,
    String? note,
  }) {
    if (approvalId.startsWith('leave::')) {
      final requestId = approvalId.replaceFirst('leave::', '');
      final current = _leaveById[requestId];
      if (current == null) {
        throw StateError('Leave approval with id $approvalId not found');
      }

      final nextSteps = _applyApprovalStep(
        steps: current.approvalSteps,
        approverId: approverId,
        approverName: approverName,
        status: status,
        note: note,
      );
      final nextStatus = _leaveStatusFromApproval(nextSteps);
      final updated = current.copyWith(
        approvalSteps: nextSteps,
        status: nextStatus,
        note: note ?? current.note,
      );
      _leaveById[requestId] = updated;
      return _leaveToApprovalItem(updated);
    }

    if (approvalId.startsWith('wfa::')) {
      final requestId = approvalId.replaceFirst('wfa::', '');
      final current = _wfaById[requestId];
      if (current == null) {
        throw StateError('WFA approval with id $approvalId not found');
      }

      final nextSteps = _applyApprovalStep(
        steps: current.approvalSteps,
        approverId: approverId,
        approverName: approverName,
        status: status,
        note: note,
      );
      final nextStatus = _wfaStatusFromApproval(nextSteps);
      final updated = current.copyWith(
        approvalSteps: nextSteps,
        status: nextStatus,
        note: note ?? current.note,
      );
      _wfaById[requestId] = updated;
      return _wfaToApprovalItem(updated);
    }

    throw StateError('Unknown approval id: $approvalId');
  }

  bool _isPendingForApprover(List<ApprovalStep> steps, String approverId) {
    final currentStep = _currentPendingStep(steps);
    return currentStep?.approverId == approverId;
  }

  ApprovalStep? _currentPendingStep(List<ApprovalStep> steps) {
    for (final step in steps) {
      if (step.status == ApprovalStepStatus.pending) {
        return step;
      }
    }
    return null;
  }

  List<ApprovalStep> _applyApprovalStep({
    required List<ApprovalStep> steps,
    required String approverId,
    required String approverName,
    required ApprovalStepStatus status,
    String? note,
  }) {
    var updatedCurrent = false;
    return steps.map((step) {
      if (!updatedCurrent &&
          step.status == ApprovalStepStatus.pending &&
          step.approverId == approverId) {
        updatedCurrent = true;
        return step.copyWith(
          status: status,
          approverId: approverId,
          approverName: approverName,
          note: note ?? step.note,
          actedAt: DateTime.now(),
        );
      }
      return step;
    }).toList();
  }

  leave_model.WorkflowStatus _leaveStatusFromApproval(
      List<ApprovalStep> steps) {
    if (steps.any((step) => step.status == ApprovalStepStatus.rejected)) {
      return leave_model.WorkflowStatus.rejected;
    }
    if (steps.isEmpty ||
        steps.every((step) => step.status == ApprovalStepStatus.approved)) {
      return leave_model.WorkflowStatus.approved;
    }
    return leave_model.WorkflowStatus.pending;
  }

  wfa_model.WorkflowStatus _wfaStatusFromApproval(List<ApprovalStep> steps) {
    if (steps.any((step) => step.status == ApprovalStepStatus.rejected)) {
      return wfa_model.WorkflowStatus.rejected;
    }
    if (steps.isEmpty ||
        steps.every((step) => step.status == ApprovalStepStatus.approved)) {
      return wfa_model.WorkflowStatus.approved;
    }
    return wfa_model.WorkflowStatus.pending;
  }

  ApprovalItem _leaveToApprovalItem(leave_model.LeaveRequestRecord record) {
    return ApprovalItem(
      id: 'leave::${record.id}',
      module: ApprovalModule.leave,
      referenceId: record.id,
      requesterId: record.requesterId,
      requesterName: record.requesterName,
      requesterRole: record.requesterRole,
      title: record.category.name,
      summary: record.reason,
      status: _approvalItemStatus(record.approvalSteps),
      submittedAt: record.submittedAt,
      approvalSteps: record.approvalSteps,
    );
  }

  ApprovalItem _wfaToApprovalItem(wfa_model.WfaRequestRecord record) {
    return ApprovalItem(
      id: 'wfa::${record.id}',
      module: ApprovalModule.wfa,
      referenceId: record.id,
      requesterId: record.requesterId,
      requesterName: record.requesterName,
      requesterRole: record.requesterRole,
      title: record.mode.name,
      summary: record.reason,
      status: _approvalItemStatus(record.approvalSteps),
      submittedAt: record.submittedAt,
      approvalSteps: record.approvalSteps,
    );
  }

  ApprovalStepStatus _approvalItemStatus(List<ApprovalStep> steps) {
    if (steps.any((step) => step.status == ApprovalStepStatus.rejected)) {
      return ApprovalStepStatus.rejected;
    }
    if (steps.isNotEmpty &&
        steps.every((step) => step.status == ApprovalStepStatus.approved)) {
      return ApprovalStepStatus.approved;
    }
    return ApprovalStepStatus.pending;
  }
}
