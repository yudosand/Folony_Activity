import '../../models/attendance_record.dart';
import '../attendance_repository.dart';
import 'workflow_repository_mode.dart';

class FallbackAttendanceRepository implements AttendanceRepository {
  const FallbackAttendanceRepository({
    required this.mode,
    required AttendanceRepository remote,
    required AttendanceRepository local,
  })  : _remote = remote,
        _local = local;

  final WorkflowRepositoryMode mode;
  final AttendanceRepository _remote;
  final AttendanceRepository _local;

  @override
  Future<List<AttendanceRecord>> listByUser({
    required String userId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return _guard(
      remote: () => _remote.listByUser(
        userId: userId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
      local: () => _local.listByUser(
        userId: userId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      ),
    );
  }

  @override
  Future<AttendanceRecord> createRecord(AttendanceRecord record) {
    return _guard(
      remote: () => _remote.createRecord(record),
      local: () => _local.createRecord(record),
    );
  }

  @override
  Future<AttendanceRecord> latestRecordForToday({
    required String userId,
  }) {
    return _guard(
      remote: () => _remote.latestRecordForToday(userId: userId),
      local: () => _local.latestRecordForToday(userId: userId),
    );
  }

  @override
  Future<void> clearByUser({
    required String userId,
  }) {
    return _guard(
      remote: () => _remote.clearByUser(userId: userId),
      local: () => _local.clearByUser(userId: userId),
    );
  }

  Future<T> _guard<T>({
    required Future<T> Function() remote,
    required Future<T> Function() local,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return local();
    }
    try {
      return await remote();
    } catch (_) {
      return local();
    }
  }
}
