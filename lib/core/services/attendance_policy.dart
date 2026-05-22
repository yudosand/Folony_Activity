import '../models/attendance_record.dart';
import '../models/wfa_request_record.dart';

class AttendancePolicy {
  static const String officeStart = '08:30';
  static const String officeEnd = '17:00';

  const AttendancePolicy._();

  static AttendanceDayInsight evaluate({
    required List<AttendanceRecord> attendanceRecords,
    required List<WfaRequestRecord> wfaRequests,
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final todayRecords = attendanceRecords
        .where((item) => _isSameDate(item.workDate, now))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    AttendanceRecord? checkInRecord;
    AttendanceRecord? checkOutRecord;
    for (final record in todayRecords) {
      if (record.action == AttendanceAction.checkIn &&
          record.status == AttendanceRecordStatus.success &&
          checkInRecord == null) {
        checkInRecord = record;
      }
      if (record.action == AttendanceAction.checkOut &&
          record.status == AttendanceRecordStatus.success) {
        checkOutRecord = record;
      }
    }

    final regularWfa = wfaRequests.where((item) {
      return _isSameDate(item.workDate, now) &&
          item.mode == WfaRequestMode.regular &&
          _isActiveWorkflow(item.status);
    }).toList();

    final overtimeWfa = wfaRequests.where((item) {
      return _isSameDate(item.workDate, now) &&
          item.mode == WfaRequestMode.overtime &&
          _isActiveWorkflow(item.status);
    }).toList();

    final shiftCompensationOvertime = overtimeWfa
        .where((item) => item.compensationMode == WfaCompensationMode.shiftMundur)
        .toList();

    final startBoundary = _timeOnDate(now, officeStart);
    final endBoundary = _timeOnDate(now, officeEnd);
    final checkInAt = checkInRecord?.recordedAt;
    final checkOutAt = checkOutRecord?.recordedAt;

    final workDuration = checkInAt == null || checkOutAt == null
        ? Duration.zero
        : checkOutAt.difference(checkInAt);
    final lateDuration = checkInAt != null && checkInAt.isAfter(startBoundary)
        ? checkInAt.difference(startBoundary)
        : Duration.zero;
    final earlyArrivalDuration =
        checkInAt != null && checkInAt.isBefore(startBoundary)
            ? startBoundary.difference(checkInAt)
            : Duration.zero;
    final earlyLeaveDuration = checkOutAt != null && checkOutAt.isBefore(endBoundary)
        ? endBoundary.difference(checkOutAt)
        : Duration.zero;
    final attendanceOvertime =
        checkOutAt != null && checkOutAt.isAfter(endBoundary)
            ? checkOutAt.difference(endBoundary)
            : Duration.zero;
    final wfaOvertimeDuration = overtimeWfa.fold<Duration>(
      Duration.zero,
      (sum, item) => sum + _windowDuration(item.startTime, item.endTime),
    );
    final effectiveOvertime = attendanceOvertime > Duration.zero
        ? attendanceOvertime
        : wfaOvertimeDuration;

    final arrivalLabel = checkInAt == null
        ? 'Belum check-in'
        : lateDuration > Duration.zero
            ? 'Terlambat'
            : earlyArrivalDuration > Duration.zero
                ? 'Lebih awal'
                : 'Tepat waktu';
    final arrivalNote = checkInAt == null
        ? 'Target masuk $officeStart.'
        : lateDuration > Duration.zero
            ? 'Terlambat ${_formatDuration(lateDuration)} dari jadwal $officeStart.'
            : earlyArrivalDuration > Duration.zero
                ? 'Lebih awal ${_formatDuration(earlyArrivalDuration)} dari jadwal $officeStart.'
                : 'Tepat waktu sesuai jadwal $officeStart.';

    final departureLabel = checkOutAt == null
        ? 'Belum check-out'
        : effectiveOvertime > Duration.zero
            ? 'Lembur'
            : earlyLeaveDuration > Duration.zero
                ? 'Pulang cepat'
                : 'Sesuai jadwal';
    final departureNote = checkOutAt == null
        ? 'Target pulang $officeEnd.'
        : effectiveOvertime > Duration.zero
            ? 'Pulang ${_formatDuration(effectiveOvertime)} setelah jadwal $officeEnd.'
            : earlyLeaveDuration > Duration.zero
                ? 'Pulang lebih cepat ${_formatDuration(earlyLeaveDuration)} dari jadwal $officeEnd.'
                : 'Pulang sesuai jadwal $officeEnd.';

    String summaryLabel;
    if (checkInAt == null) {
      summaryLabel = 'Belum mulai';
    } else if (checkOutAt == null) {
      summaryLabel = 'Sesi aktif';
    } else if (effectiveOvertime > Duration.zero) {
      summaryLabel = 'Lembur';
    } else if (earlyLeaveDuration > Duration.zero) {
      summaryLabel = 'Pulang cepat';
    } else if (lateDuration > Duration.zero) {
      summaryLabel = 'Terlambat';
    } else {
      summaryLabel = 'Normal';
    }

    final nextStartRecommendation = shiftCompensationOvertime.isEmpty
        ? null
        : _recommendedNextStart(
            officeStart,
            shiftCompensationOvertime.fold<Duration>(
              Duration.zero,
              (sum, item) => sum + _windowDuration(item.startTime, item.endTime),
            ),
          );

    final contextNotes = <String>[];
    if (regularWfa.isNotEmpty) {
      contextNotes.add(
        'WFA reguler hari ini tercatat untuk jam kerja utama.',
      );
    }
    if (overtimeWfa.isNotEmpty) {
      contextNotes.add(
        'WFA overtime hari ini tercatat ${_formatDuration(wfaOvertimeDuration)}.',
      );
    }
    if (nextStartRecommendation != null) {
      contextNotes.add(
        'Rekomendasi jam masuk esok hari: $nextStartRecommendation.',
      );
    }

    final summaryNote = checkInAt == null
        ? 'Jam kerja standar $officeStart - $officeEnd.'
        : checkOutAt == null
            ? 'Durasi kerja akan dihitung setelah check-out.'
            : 'Total durasi kerja hari ini ${_formatDuration(workDuration)}.';

    return AttendanceDayInsight(
      checkInAt: checkInAt,
      checkOutAt: checkOutAt,
      arrivalLabel: arrivalLabel,
      arrivalNote: arrivalNote,
      departureLabel: departureLabel,
      departureNote: departureNote,
      summaryLabel: summaryLabel,
      summaryNote: summaryNote,
      workDuration: workDuration,
      lateDuration: lateDuration,
      earlyLeaveDuration: earlyLeaveDuration,
      overtimeDuration: effectiveOvertime,
      hasRegularWfa: regularWfa.isNotEmpty,
      hasOvertimeWfa: overtimeWfa.isNotEmpty,
      nextStartRecommendation: nextStartRecommendation,
      contextNotes: contextNotes,
    );
  }

  static bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static bool _isActiveWorkflow(WorkflowStatus status) {
    return status == WorkflowStatus.approved ||
        status == WorkflowStatus.active ||
        status == WorkflowStatus.completed;
  }

  static DateTime _timeOnDate(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static Duration _windowDuration(String start, String end) {
    final base = DateTime(2026, 1, 1);
    final startTime = _timeOnDate(base, start);
    final endTime = _timeOnDate(base, end);
    if (endTime.isBefore(startTime)) {
      return Duration.zero;
    }
    return endTime.difference(startTime);
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours == 0) {
      return '$minutes menit';
    }

    if (minutes == 0) {
      return '$hours jam';
    }

    return '${hours}j ${minutes}m';
  }

  static String _recommendedNextStart(String baseline, Duration delay) {
    final baselineTime = _timeOnDate(DateTime(2026, 1, 1), baseline);
    final adjusted = baselineTime.add(delay);
    final hour = adjusted.hour.toString().padLeft(2, '0');
    final minute = adjusted.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class AttendanceDayInsight {
  const AttendanceDayInsight({
    required this.checkInAt,
    required this.checkOutAt,
    required this.arrivalLabel,
    required this.arrivalNote,
    required this.departureLabel,
    required this.departureNote,
    required this.summaryLabel,
    required this.summaryNote,
    required this.workDuration,
    required this.lateDuration,
    required this.earlyLeaveDuration,
    required this.overtimeDuration,
    required this.hasRegularWfa,
    required this.hasOvertimeWfa,
    required this.nextStartRecommendation,
    required this.contextNotes,
  });

  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String arrivalLabel;
  final String arrivalNote;
  final String departureLabel;
  final String departureNote;
  final String summaryLabel;
  final String summaryNote;
  final Duration workDuration;
  final Duration lateDuration;
  final Duration earlyLeaveDuration;
  final Duration overtimeDuration;
  final bool hasRegularWfa;
  final bool hasOvertimeWfa;
  final String? nextStartRecommendation;
  final List<String> contextNotes;
}
