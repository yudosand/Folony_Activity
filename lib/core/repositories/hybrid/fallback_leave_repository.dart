import '../../models/leave_request_record.dart';
import '../leave_repository.dart';
import 'workflow_repository_mode.dart';

class FallbackLeaveRepository implements LeaveRepository {
  const FallbackLeaveRepository({
    required this.mode,
    required LeaveRepository remote,
    required LeaveRepository local,
  })  : _remote = remote,
        _local = local;

  final WorkflowRepositoryMode mode;
  final LeaveRepository _remote;
  final LeaveRepository _local;

  @override
  Future<List<LeaveRequestRecord>> listByUser({
    required String userId,
  }) async {
    return _guard(
      remote: () => _remote.listByUser(userId: userId),
      local: () => _local.listByUser(userId: userId),
    );
  }

  @override
  Future<List<LeaveRequestRecord>> listForApprover({
    required String approverId,
  }) async {
    return _guard(
      remote: () => _remote.listForApprover(approverId: approverId),
      local: () => _local.listForApprover(approverId: approverId),
    );
  }

  @override
  Future<LeaveRequestRecord> submit(LeaveRequestRecord request) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.submit(request);
    }
    return _remote.submit(request);
  }

  @override
  Future<LeaveRequestRecord> updateStatus({
    required String requestId,
    required WorkflowStatus status,
    String? note,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.updateStatus(
        requestId: requestId,
        status: status,
        note: note,
      );
    }
    return _remote.updateStatus(
      requestId: requestId,
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
