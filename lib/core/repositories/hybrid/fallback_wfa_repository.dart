import '../../models/wfa_request_record.dart';
import '../wfa_repository.dart';
import 'workflow_repository_mode.dart';

class FallbackWfaRepository implements WfaRepository {
  const FallbackWfaRepository({
    required this.mode,
    required WfaRepository remote,
    required WfaRepository local,
  })  : _remote = remote,
        _local = local;

  final WorkflowRepositoryMode mode;
  final WfaRepository _remote;
  final WfaRepository _local;

  @override
  Future<List<WfaRequestRecord>> listByUser({
    required String userId,
  }) async {
    return _guard(
      remote: () => _remote.listByUser(userId: userId),
      local: () => _local.listByUser(userId: userId),
    );
  }

  @override
  Future<List<WfaRequestRecord>> listForApprover({
    required String approverId,
  }) async {
    return _guard(
      remote: () => _remote.listForApprover(approverId: approverId),
      local: () => _local.listForApprover(approverId: approverId),
    );
  }

  @override
  Future<WfaRequestRecord> submit(WfaRequestRecord request) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.submit(request);
    }
    return _remote.submit(request);
  }

  @override
  Future<WfaRequestRecord> updateStatus({
    required String requestId,
    required WorkflowStatus status,
    DateTime? actualStartAt,
    DateTime? actualEndAt,
    String? note,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.updateStatus(
        requestId: requestId,
        status: status,
        actualStartAt: actualStartAt,
        actualEndAt: actualEndAt,
        note: note,
      );
    }
    return _remote.updateStatus(
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
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.appendTaskUpdate(
        requestId: requestId,
        update: update,
      );
    }
    return _remote.appendTaskUpdate(
      requestId: requestId,
      update: update,
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
