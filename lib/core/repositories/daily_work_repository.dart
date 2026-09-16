import '../models/daily_work_update.dart';
import '../network/simple_api_client.dart';

class DailyWorkRepository {
  DailyWorkRepository({SimpleApiClient? client}) : _client = client;
  final SimpleApiClient? _client;
  final Map<String, List<DailyWorkUpdate>> _local = {};

  Future<List<DailyWorkUpdate>> load(String userId) async {
    if (_client == null) return List.of(_local[userId] ?? []);
    final response = await _client.get('/employee-activities');
    return (response['data'] as List)
        .map((row) =>
            DailyWorkUpdate.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<DailyWorkUpdate> save({
    required String userId,
    required String requestId,
    required String note,
    required bool isFinished,
    String? photoUrl,
  }) async {
    if (_client != null) {
      final response = await _client.post('/employee-activities', body: {
        'request_id': requestId,
        'note': note,
        'photo_url': photoUrl,
        'is_finished': isFinished,
      });
      return DailyWorkUpdate.fromJson(
          Map<String, dynamic>.from(response['data'] as Map));
    }
    final rows = _local.putIfAbsent(userId, () => []);
    final latest = rows.isEmpty ? null : rows.first;
    final now = DateTime.now();
    final update = DailyWorkUpdate(
      note: note,
      createdAt: now,
      startedAt: latest != null && !latest.isFinished ? latest.startedAt : now,
      photoPath: photoUrl,
      isFinished: isFinished,
    );
    rows.insert(0, update);
    return update;
  }
}
