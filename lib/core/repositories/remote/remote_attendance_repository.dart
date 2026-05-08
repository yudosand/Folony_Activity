import '../../models/attendance_record.dart';
import '../../network/simple_api_client.dart';
import '../attendance_repository.dart';

class RemoteAttendanceRepository implements AttendanceRepository {
  const RemoteAttendanceRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<List<AttendanceRecord>> listByUser({
    required String userId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final response = await _client.get(
      '/attendance',
      queryParameters: {
        if (dateFrom != null) 'date_from': dateFrom.toIso8601String(),
        if (dateTo != null) 'date_to': dateTo.toIso8601String(),
      },
    );
    return _decodeList(response);
  }

  @override
  Future<AttendanceRecord> createRecord(AttendanceRecord record) async {
    final endpoint = switch (record.action) {
      AttendanceAction.checkIn => '/attendance/check-in',
      AttendanceAction.checkOut => '/attendance/check-out',
    };
    final response = await _client.post(endpoint, body: record.toJson());
    return _decodeOne(response);
  }

  @override
  Future<AttendanceRecord> latestRecordForToday({
    required String userId,
  }) async {
    final now = DateTime.now();
    final records = await listByUser(
      userId: userId,
      dateFrom: DateTime(now.year, now.month, now.day),
      dateTo: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    if (records.isEmpty) {
      throw StateError('No attendance record found for $userId today');
    }
    return records.first;
  }

  @override
  Future<void> clearByUser({
    required String userId,
  }) async {
    await _client.delete('/attendance');
  }

  List<AttendanceRecord> _decodeList(dynamic response) {
    final rawList = _unwrapList(response);
    return rawList.map(AttendanceRecord.fromJson).toList();
  }

  AttendanceRecord _decodeOne(dynamic response) {
    return AttendanceRecord.fromJson(_unwrapMap(response));
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
