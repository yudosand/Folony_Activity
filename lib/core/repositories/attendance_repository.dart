import '../models/attendance_record.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceRecord>> listByUser({
    required String userId,
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  Future<AttendanceRecord> createRecord(AttendanceRecord record);

  Future<AttendanceRecord> latestRecordForToday({
    required String userId,
  });

  Future<void> clearByUser({
    required String userId,
  });
}
