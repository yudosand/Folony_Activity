import 'package:flutter_test/flutter_test.dart';

import 'package:folony_activity/core/enums/app_role.dart';
import 'package:folony_activity/core/models/approval_step.dart';
import 'package:folony_activity/core/models/attendance_record.dart';
import 'package:folony_activity/core/models/wfa_request_record.dart';
import 'package:folony_activity/core/services/attendance_policy.dart';

void main() {
  test('attendance policy marks late arrival and early leave', () {
    final workDate = DateTime(2026, 4, 24);
    final insight = AttendancePolicy.evaluate(
      attendanceRecords: [
        AttendanceRecord(
          id: 'checkin',
          userId: 'staff:nadia',
          workDate: workDate,
          action: AttendanceAction.checkIn,
          status: AttendanceRecordStatus.success,
          recordedAt: DateTime(2026, 4, 24, 8, 45),
          location: AttendanceLocationRecord(
            latitude: -6.2,
            longitude: 106.8,
            recordedAt: DateTime(2026, 4, 24, 8, 45),
          ),
        ),
        AttendanceRecord(
          id: 'checkout',
          userId: 'staff:nadia',
          workDate: workDate,
          action: AttendanceAction.checkOut,
          status: AttendanceRecordStatus.success,
          recordedAt: DateTime(2026, 4, 24, 16, 30),
          location: AttendanceLocationRecord(
            latitude: -6.2,
            longitude: 106.8,
            recordedAt: DateTime(2026, 4, 24, 16, 30),
          ),
        ),
      ],
      wfaRequests: const [],
      referenceNow: DateTime(2026, 4, 24, 16, 40),
    );

    expect(insight.arrivalLabel, 'Terlambat');
    expect(insight.departureLabel, 'Pulang cepat');
    expect(insight.lateDuration, const Duration(minutes: 15));
    expect(insight.earlyLeaveDuration, const Duration(minutes: 30));
  });

  test('attendance policy uses overtime WFA for next-day recommendation', () {
    final workDate = DateTime(2026, 4, 24);
    final insight = AttendancePolicy.evaluate(
      attendanceRecords: [
        AttendanceRecord(
          id: 'checkin',
          userId: 'staff:nadia',
          workDate: workDate,
          action: AttendanceAction.checkIn,
          status: AttendanceRecordStatus.success,
          recordedAt: DateTime(2026, 4, 24, 8, 30),
          location: AttendanceLocationRecord(
            latitude: -6.2,
            longitude: 106.8,
            recordedAt: DateTime(2026, 4, 24, 8, 30),
          ),
        ),
        AttendanceRecord(
          id: 'checkout',
          userId: 'staff:nadia',
          workDate: workDate,
          action: AttendanceAction.checkOut,
          status: AttendanceRecordStatus.success,
          recordedAt: DateTime(2026, 4, 24, 17, 0),
          location: AttendanceLocationRecord(
            latitude: -6.2,
            longitude: 106.8,
            recordedAt: DateTime(2026, 4, 24, 17, 0),
          ),
        ),
      ],
      wfaRequests: [
        WfaRequestRecord(
          id: 'wfa-overtime',
          requesterId: 'staff:nadia',
          requesterName: 'Nadia Staff',
          requesterRole: AppRole.staff,
          mode: WfaRequestMode.overtime,
          compensationMode: WfaCompensationMode.shiftMundur,
          workDate: workDate,
          startTime: '19:30',
          endTime: '21:00',
          locationLabel: 'Online meeting',
          reason: 'Meeting malam',
          initialTask: 'Presentasi',
          status: WorkflowStatus.approved,
          approvalSteps: const [
            ApprovalStep(
              sequence: 1,
              approverRole: AppRole.spv,
              status: ApprovalStepStatus.approved,
              approverId: 'spv:dimas spv',
              approverName: 'Dimas SPV',
            ),
          ],
          taskUpdates: const [],
          submittedAt: DateTime(2026, 4, 24, 12, 0),
        ),
      ],
      referenceNow: DateTime(2026, 4, 24, 21, 30),
    );

    expect(insight.hasOvertimeWfa, isTrue);
    expect(insight.overtimeDuration, const Duration(hours: 1, minutes: 30));
    expect(insight.nextStartRecommendation, '10:00');
  });

  test('attendance policy keeps work duration empty until checkout exists', () {
    final workDate = DateTime(2026, 4, 24);
    final insight = AttendancePolicy.evaluate(
      attendanceRecords: [
        AttendanceRecord(
          id: 'checkin-only',
          userId: 'staff:nadia',
          workDate: workDate,
          action: AttendanceAction.checkIn,
          status: AttendanceRecordStatus.success,
          recordedAt: DateTime(2026, 4, 24, 8, 30),
          location: AttendanceLocationRecord(
            latitude: -6.2,
            longitude: 106.8,
            recordedAt: DateTime(2026, 4, 24, 8, 30),
          ),
        ),
      ],
      wfaRequests: const [],
      referenceNow: DateTime(2026, 4, 24, 12),
    );

    expect(insight.summaryLabel, 'Sesi aktif');
    expect(insight.workDuration, Duration.zero);
    expect(
      insight.summaryNote,
      'Durasi kerja akan dihitung setelah check-out.',
    );
  });
}
