import '../models/approval_item.dart';
import '../models/approval_step.dart';

abstract class ApprovalRepository {
  Future<List<ApprovalItem>> listInbox({
    required String approverId,
    ApprovalModule? module,
  });

  Future<ApprovalItem> approve({
    required String approvalId,
    required String approverId,
    required String approverName,
    String? note,
  });

  Future<ApprovalItem> reject({
    required String approvalId,
    required String approverId,
    required String approverName,
    String? note,
  });

  Future<ApprovalItem> moveToStatus({
    required String approvalId,
    required String approverId,
    required String approverName,
    required ApprovalStepStatus status,
    String? note,
  });
}
