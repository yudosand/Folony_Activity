import '../../models/leave_request_record.dart';
import '../leave_repository.dart';
import 'mock_workflow_store.dart';

class MockLeaveRepository implements LeaveRepository {
  MockLeaveRepository({MockWorkflowStore? store})
      : _store = store ?? MockWorkflowStore.instance;

  final MockWorkflowStore _store;

  @override
  Future<List<LeaveRequestRecord>> listByUser({
    required String userId,
  }) async {
    return _store.listLeaveByUser(userId);
  }

  @override
  Future<List<LeaveRequestRecord>> listForApprover({
    required String approverId,
  }) async {
    return _store.listLeaveForApprover(approverId);
  }

  @override
  Future<LeaveRequestRecord> submit(LeaveRequestRecord request) async {
    return _store.upsertLeave(request);
  }

  @override
  Future<LeaveRequestRecord> updateStatus({
    required String requestId,
    required WorkflowStatus status,
    String? note,
  }) async {
    return _store.updateLeaveStatus(
      requestId: requestId,
      status: status,
      note: note,
    );
  }
}
