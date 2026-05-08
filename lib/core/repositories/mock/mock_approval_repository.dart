import '../../models/approval_item.dart';
import '../../models/approval_step.dart';
import '../approval_repository.dart';
import 'mock_workflow_store.dart';

class MockApprovalRepository implements ApprovalRepository {
  MockApprovalRepository({MockWorkflowStore? store})
      : _store = store ?? MockWorkflowStore.instance;

  final MockWorkflowStore _store;

  @override
  Future<List<ApprovalItem>> listInbox({
    required String approverId,
    ApprovalModule? module,
  }) async {
    return _store.listApprovalInbox(
      approverId: approverId,
      module: module,
    );
  }

  @override
  Future<ApprovalItem> approve({
    required String approvalId,
    required String approverId,
    required String approverName,
    String? note,
  }) async {
    return moveToStatus(
      approvalId: approvalId,
      approverId: approverId,
      approverName: approverName,
      status: ApprovalStepStatus.approved,
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
    return moveToStatus(
      approvalId: approvalId,
      approverId: approverId,
      approverName: approverName,
      status: ApprovalStepStatus.rejected,
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
    return _store.updateApprovalStatus(
      approvalId: approvalId,
      approverId: approverId,
      approverName: approverName,
      status: status,
      note: note,
    );
  }
}
