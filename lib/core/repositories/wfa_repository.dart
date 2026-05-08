import '../models/wfa_request_record.dart';

abstract class WfaRepository {
  Future<List<WfaRequestRecord>> listByUser({
    required String userId,
  });

  Future<List<WfaRequestRecord>> listForApprover({
    required String approverId,
  });

  Future<WfaRequestRecord> submit(WfaRequestRecord request);

  Future<WfaRequestRecord> updateStatus({
    required String requestId,
    required WorkflowStatus status,
    DateTime? actualStartAt,
    DateTime? actualEndAt,
    String? note,
  });

  Future<WfaRequestRecord> appendTaskUpdate({
    required String requestId,
    required WfaTaskUpdateRecord update,
  });
}
