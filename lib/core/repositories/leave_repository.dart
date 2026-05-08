import '../models/leave_request_record.dart';

abstract class LeaveRepository {
  Future<List<LeaveRequestRecord>> listByUser({
    required String userId,
  });

  Future<List<LeaveRequestRecord>> listForApprover({
    required String approverId,
  });

  Future<LeaveRequestRecord> submit(LeaveRequestRecord request);

  Future<LeaveRequestRecord> updateStatus({
    required String requestId,
    required WorkflowStatus status,
    String? note,
  });
}
