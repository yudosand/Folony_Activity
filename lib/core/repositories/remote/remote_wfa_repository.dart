import '../../models/wfa_request_record.dart';
import '../../network/simple_api_client.dart';
import '../wfa_repository.dart';

class RemoteWfaRepository implements WfaRepository {
  const RemoteWfaRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<List<WfaRequestRecord>> listByUser({
    required String userId,
  }) async {
    final response = await _client.get(
      '/wfa',
      queryParameters: {'user_id': userId},
    );
    return _decodeList(response);
  }

  @override
  Future<List<WfaRequestRecord>> listForApprover({
    required String approverId,
  }) async {
    final response = await _client.get(
      '/wfa/approvals',
      queryParameters: {'approver_id': approverId},
    );
    return _decodeList(response);
  }

  @override
  Future<WfaRequestRecord> submit(WfaRequestRecord request) async {
    final response = await _client.post(
      '/wfa',
      body: request.toJson(),
    );
    return _decodeOne(response);
  }

  @override
  Future<WfaRequestRecord> updateStatus({
    required String requestId,
    required WorkflowStatus status,
    DateTime? actualStartAt,
    DateTime? actualEndAt,
    String? note,
  }) async {
    final response = await _client.patch(
      '/wfa/$requestId/status',
      body: {
        'status': status.name,
        'actual_start_at': actualStartAt?.toIso8601String(),
        'actual_end_at': actualEndAt?.toIso8601String(),
        'note': note,
      },
    );
    return _decodeOne(response);
  }

  @override
  Future<WfaRequestRecord> appendTaskUpdate({
    required String requestId,
    required WfaTaskUpdateRecord update,
  }) async {
    final response = await _client.post(
      '/wfa/$requestId/task-updates',
      body: update.toJson(),
    );
    return _decodeOne(response);
  }

  List<WfaRequestRecord> _decodeList(dynamic response) {
    final rawList = _unwrapList(response);
    return rawList.map(WfaRequestRecord.fromJson).toList();
  }

  WfaRequestRecord _decodeOne(dynamic response) {
    return WfaRequestRecord.fromJson(_unwrapMap(response));
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
