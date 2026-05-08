import '../../models/leave_request_record.dart';
import '../../network/simple_api_client.dart';
import '../leave_repository.dart';

class RemoteLeaveRepository implements LeaveRepository {
  const RemoteLeaveRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<List<LeaveRequestRecord>> listByUser({
    required String userId,
  }) async {
    final response = await _client.get(
      '/leave',
      queryParameters: {'user_id': userId},
    );
    return _decodeList(response);
  }

  @override
  Future<List<LeaveRequestRecord>> listForApprover({
    required String approverId,
  }) async {
    final response = await _client.get(
      '/leave/approvals',
      queryParameters: {'approver_id': approverId},
    );
    return _decodeList(response);
  }

  @override
  Future<LeaveRequestRecord> submit(LeaveRequestRecord request) async {
    final response = await _client.post(
      '/leave',
      body: request.toJson(),
    );
    return _decodeOne(response);
  }

  @override
  Future<LeaveRequestRecord> updateStatus({
    required String requestId,
    required WorkflowStatus status,
    String? note,
  }) async {
    final response = await _client.patch(
      '/leave/$requestId/status',
      body: {
        'status': status.name,
        'note': note,
      },
    );
    return _decodeOne(response);
  }

  List<LeaveRequestRecord> _decodeList(dynamic response) {
    final rawList = _unwrapList(response);
    return rawList.map(LeaveRequestRecord.fromJson).toList();
  }

  LeaveRequestRecord _decodeOne(dynamic response) {
    return LeaveRequestRecord.fromJson(_unwrapMap(response));
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
