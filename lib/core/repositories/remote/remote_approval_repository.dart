import '../../models/approval_item.dart';
import '../../models/approval_step.dart';
import '../../network/simple_api_client.dart';
import '../approval_repository.dart';

class RemoteApprovalRepository implements ApprovalRepository {
  const RemoteApprovalRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<List<ApprovalItem>> listInbox({
    required String approverId,
    ApprovalModule? module,
  }) async {
    final response = await _client.get(
      '/approvals/inbox',
      queryParameters: {
        'approver_id': approverId,
        if (module != null) 'module': module.name,
      },
    );
    final rawList = _unwrapList(response);
    return rawList.map(ApprovalItem.fromJson).toList();
  }

  @override
  Future<ApprovalItem> approve({
    required String approvalId,
    required String approverId,
    required String approverName,
    String? note,
  }) async {
    final response = await _client.post(
      '/approvals/$approvalId/approve',
      body: {
        'approver_id': approverId,
        'approver_name': approverName,
        'note': note,
      },
    );
    return ApprovalItem.fromJson(_unwrapMap(response));
  }

  @override
  Future<ApprovalItem> reject({
    required String approvalId,
    required String approverId,
    required String approverName,
    String? note,
  }) async {
    final response = await _client.post(
      '/approvals/$approvalId/reject',
      body: {
        'approver_id': approverId,
        'approver_name': approverName,
        'note': note,
      },
    );
    return ApprovalItem.fromJson(_unwrapMap(response));
  }

  @override
  Future<ApprovalItem> moveToStatus({
    required String approvalId,
    required String approverId,
    required String approverName,
    required ApprovalStepStatus status,
    String? note,
  }) async {
    final path = status == ApprovalStepStatus.rejected
        ? '/approvals/$approvalId/reject'
        : '/approvals/$approvalId/approve';
    final response = await _client.post(
      path,
      body: {
        'approver_id': approverId,
        'approver_name': approverName,
        'note': note,
      },
    );
    return ApprovalItem.fromJson(_unwrapMap(response));
  }

  List<Map<String, dynamic>> _unwrapList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _unwrapMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return response;
    }
    if (response is Map) {
      if (response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return Map<String, dynamic>.from(response);
    }
    return const {};
  }
}
