import '../../models/app_session.dart';
import '../../models/performance_summary.dart';
import '../../network/simple_api_client.dart';
import '../performance_repository.dart';

class RemotePerformanceRepository implements PerformanceRepository {
  const RemotePerformanceRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<PerformanceSummary?> currentSummary({
    required AppSession session,
  }) async {
    final response = await _client.get('/performance/summary');
    final payload = _unwrapMap(response);
    if (payload.isEmpty) {
      return null;
    }
    return PerformanceSummary.fromJson(payload);
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
