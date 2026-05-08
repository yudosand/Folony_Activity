import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folony_activity/app/app_controller.dart';
import 'package:folony_activity/core/enums/app_role.dart';
import 'package:folony_activity/core/models/app_session.dart';
import 'package:folony_activity/features/attendance/presentation/attendance_page.dart';

void main() {
  testWidgets('face check-in button is enabled when GPS is active',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AttendancePage(
          session: AppSession.mock(AppRole.fgg),
          controller: AppController(),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Face Check-in'),
    );

    expect(button.onPressed, isNotNull);
  });
}
