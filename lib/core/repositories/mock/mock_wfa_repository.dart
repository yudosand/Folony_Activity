import '../../models/wfa_request_record.dart';
import '../wfa_repository.dart';
import 'mock_workflow_store.dart';

class MockWfaRepository implements WfaRepository {
  MockWfaRepository({MockWorkflowStore? store})
      : _store = store ?? MockWorkflowStore.instance;

  final MockWorkflowStore _store;

  @override
  Future<List<WfaRequestRecord>> listByUser({
    required String userId,
  }) async {
    return _store.listWfaByUser(userId);
  }

  @override
  Future<List<WfaRequestRecord>> listForApprover({
    required String approverId,
  }) async {
    return _store.listWfaForApprover(approverId);
  }

  @override
  Future<WfaRequestRecord> submit(WfaRequestRecord request) async {
    return _store.upsertWfa(request);
  }

  @override
  Future<WfaRequestRecord> updateStatus({
    required String requestId,
    required WorkflowStatus status,
    DateTime? actualStartAt,
    DateTime? actualEndAt,
    String? note,
  }) async {
    return _store.updateWfaStatus(
      requestId: requestId,
      status: status,
      actualStartAt: actualStartAt,
      actualEndAt: actualEndAt,
      note: note,
    );
  }

  @override
  Future<WfaRequestRecord> appendTaskUpdate({
    required String requestId,
    required WfaTaskUpdateRecord update,
  }) async {
    return _store.appendWfaTaskUpdate(
      requestId: requestId,
      update: update,
    );
  }
}
