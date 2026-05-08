import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/attendance_record.dart';
import '../attendance_repository.dart';

class MockAttendanceRepository implements AttendanceRepository {
  MockAttendanceRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences;

  static const String _storageKey = 'mock_attendance_records_v1';
  static String? _memoryStorage;

  SharedPreferencesAsync? _preferences;

  @override
  Future<List<AttendanceRecord>> listByUser({
    required String userId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final records = await _readAll();
    final filtered = records.where((item) {
      if (item.userId != userId) {
        return false;
      }
      if (dateFrom != null && item.recordedAt.isBefore(dateFrom)) {
        return false;
      }
      if (dateTo != null && item.recordedAt.isAfter(dateTo)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return filtered;
  }

  @override
  Future<AttendanceRecord> createRecord(AttendanceRecord record) async {
    final records = await _readAll();
    records.removeWhere((item) => item.id == record.id);
    records.add(record);
    await _writeAll(records);
    return record;
  }

  @override
  Future<AttendanceRecord> latestRecordForToday({
    required String userId,
  }) async {
    final now = DateTime.now();
    final records = await listByUser(userId: userId);
    for (final record in records) {
      if (_isSameDate(record.workDate, now)) {
        return record;
      }
    }
    throw StateError('No attendance record found for $userId today');
  }

  @override
  Future<void> clearByUser({
    required String userId,
  }) async {
    final records = await _readAll();
    records.removeWhere((item) => item.userId == userId);
    await _writeAll(records);
  }

  Future<List<AttendanceRecord>> _readAll() async {
    final raw = await _getStoredPayload();
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(AttendanceRecord.fromJson)
        .toList();
  }

  Future<void> _writeAll(List<AttendanceRecord> records) async {
    final payload = records.map((item) => item.toJson()).toList();
    await _setStoredPayload(jsonEncode(payload));
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<String?> _getStoredPayload() async {
    try {
      final preferences = _preferences ??= SharedPreferencesAsync();
      return await preferences.getString(_storageKey);
    } catch (_) {
      return _memoryStorage;
    }
  }

  Future<void> _setStoredPayload(String payload) async {
    try {
      final preferences = _preferences ??= SharedPreferencesAsync();
      await preferences.setString(_storageKey, payload);
      _memoryStorage = payload;
    } catch (_) {
      _memoryStorage = payload;
    }
  }
}
