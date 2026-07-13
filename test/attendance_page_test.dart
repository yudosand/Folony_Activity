import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folony_activity/app/app_controller.dart';
import 'package:folony_activity/core/enums/app_role.dart';
import 'package:folony_activity/core/models/app_session.dart';
import 'package:folony_activity/core/models/attendance_record.dart';
import 'package:folony_activity/core/repositories/mock/mock_attendance_repository.dart';
import 'package:folony_activity/features/attendance/presentation/attendance_page.dart';

void main() {
  testWidgets('face check-in button is locked when attendance area is missing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AttendancePage(
          session: AppSession.mock(AppRole.fgg),
          controller: AppController(),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Area belum diset'),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets(
    'attendance page shows active after loading remote-like UTC check-in record',
    (tester) async {
      final repository = MockAttendanceRepository();
      final controller = AppController(
        attendanceRepository: repository,
        seedWorkflowDemoData: false,
      );
      final session = AppSession.mock(AppRole.staff);
      final now = DateTime.now();

      await controller.createAttendanceRecord(
        session,
        AttendanceRecord(
          id: 'att-utc-checkin',
          userId: session.userId,
          workDate: DateTime.utc(now.year, now.month, now.day),
          action: AttendanceAction.checkIn,
          status: AttendanceRecordStatus.success,
          recordedAt: DateTime.utc(now.year, now.month, now.day, 1, 30),
          location: AttendanceLocationRecord(
            latitude: -6.2,
            longitude: 106.8,
            recordedAt: DateTime.utc(now.year, now.month, now.day, 1, 30),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AttendancePage(
            session: session,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Check-in berhasil. Sesi kerja aktif dan siap dipantau.'),
        findsOneWidget,
      );
      expect(find.text('Belum check-in'), findsNothing);
    },
  );

  testWidgets(
    'attendance page allows a new same-day check-in after checkout',
    (tester) async {
      final repository = MockAttendanceRepository();
      final controller = AppController(
        attendanceRepository: repository,
        useRemoteAuth: true,
        useCanonicalWorkflowIds: true,
        seedWorkflowDemoData: false,
      );
      final session = AppSession.mock(AppRole.staff);
      final now = DateTime.now();
      final sameDayCheckIn = DateTime(now.year, now.month, now.day, 8, 30);
      final sameDayCheckOut = DateTime(now.year, now.month, now.day, 17, 0);

      await controller.createAttendanceRecord(
        session,
        AttendanceRecord(
          id: 'att-remote-checkin',
          userId: session.userId,
          workDate: DateTime(now.year, now.month, now.day),
          action: AttendanceAction.checkIn,
          status: AttendanceRecordStatus.success,
          recordedAt: sameDayCheckIn,
          location: AttendanceLocationRecord(
            latitude: -6.2,
            longitude: 106.8,
            recordedAt: sameDayCheckIn,
          ),
        ),
      );
      await controller.createAttendanceRecord(
        session,
        AttendanceRecord(
          id: 'att-remote-checkout',
          userId: session.userId,
          workDate: DateTime(now.year, now.month, now.day),
          action: AttendanceAction.checkOut,
          status: AttendanceRecordStatus.success,
          recordedAt: sameDayCheckOut,
          location: AttendanceLocationRecord(
            latitude: -6.2,
            longitude: 106.8,
            recordedAt: sameDayCheckOut,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AttendancePage(
            session: session,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset Mock'), findsNothing);
      expect(
        find.text('Check-out berhasil. Anda bisa memulai sesi check-in baru kapan saja.'),
        findsOneWidget,
      );
      expect(find.text('Face Check-out'), findsNothing);
    },
  );
}
