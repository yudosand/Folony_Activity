import '../../models/approval_item.dart';
import '../../models/approval_step.dart';
import '../approval_repository.dart';
import 'workflow_repository_mode.dart';

class FallbackApprovalRepository implements ApprovalRepository {
  const FallbackApprovalRepository({
    required this.mode,
    required ApprovalRepository remote,
    required ApprovalRepository local,
  })  : _remote = remote,
        _local = local;

  final WorkflowRepositoryMode mode;
  final ApprovalRepository _remote;
  final ApprovalRepository _local;

  @override
  Future<List<ApprovalItem>> listInbox({
    required String approverId,
    ApprovalModule? module,
  }) async {
    return _guard(
      remote: () => _remote.listInbox(
        approverId: approverId,
        module: module,
      ),
      local: () => _local.listInbox(
        approverId: approverId,
        module: module,
      ),
    );
  }

  @override
  Future<ApprovalItem> approve({
    required String approvalId,
    required String approverId,
    required String approverName,
    String? note,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.approve(
        approvalId: approvalId,
        approverId: approverId,
        approverName: approverName,
        note: note,
      );
    }
    return _remote.approve(
      approvalId: approvalId,
      approverId: approverId,
      approverName: approverName,
      note: note,
    );
  }

  @override
  Future<ApprovalItem> reject({
    required String approvalId,
    required String approverId,
    required String approverName,
    String? note,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.reject(
        approvalId: approvalId,
        approverId: approverId,
        approverName: approverName,
        note: note,
      );
    }
    return _remote.reject(
      approvalId: approvalId,
      approverId: approverId,
      approverName: approverName,
      note: note,
    );
  }

  @override
  Future<ApprovalItem> moveToStatus({
    required String approvalId,
    required String approverId,
    required String approverName,
    required ApprovalStepStatus status,
    String? note,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.moveToStatus(
        approvalId: approvalId,
        approverId: approverId,
        approverName: approverName,
        status: status,
        note: note,
      );
    }
    return _remote.moveToStatus(
      approvalId: approvalId,
      approverId: approverId,
      approverName: approverName,
      status: status,
      note: note,
    );
  }

  Future<T> _guard<T>({
    required Future<T> Function() remote,
    required Future<T> Function() local,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return local();
    }
    try {
      return await remote();
    } catch (_) {
      return local();
    }
  }
}
