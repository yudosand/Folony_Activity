import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folony_activity/app/app.dart';
import 'package:folony_activity/app/app_controller.dart';
import 'package:folony_activity/core/enums/app_role.dart';
import 'package:folony_activity/core/models/approval_step.dart';
import 'package:folony_activity/core/models/app_session.dart';
import 'package:folony_activity/core/models/network_entry.dart';
import 'package:folony_activity/core/models/leave_request_record.dart'
    as leave_model;
import 'package:folony_activity/core/models/wfa_request_record.dart'
    as wfa_model;
import 'package:folony_activity/features/leave/presentation/leave_page.dart';
import 'package:folony_activity/features/wfh/presentation/wfh_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  test('multi-role tester can sign in and switch roles', () async {
    final controller = AppController(
      useRemoteAuth: true,
      seedWorkflowDemoData: false,
    );

    await controller.signIn(
      identifier: AppController.multiRoleTesterIdentifier,
      password: AppController.multiRoleTesterPassword,
      fallbackRole: AppRole.staff,
    );

    expect(controller.session, isNotNull);
    expect(controller.session!.canSwitchRoles, isTrue);
    expect(controller.session!.role, AppRole.staff);

    controller.switchRole(AppRole.management);

    expect(controller.session!.role, AppRole.management);
    expect(controller.session!.canSwitchRoles, isTrue);
  });

  test('leave balance is deducted on submit and restored on rejection', () async {
    final controller = AppController(seedWorkflowDemoData: false);
    final staffSession = AppSession.mock(AppRole.staff);
    final spvSession = AppSession.mock(AppRole.spv);

    final initialBalance = controller.leaveBalanceDaysForSession(staffSession);

    await controller.submitLeaveRequest(
      staffSession,
      leave_model.LeaveRequestRecord(
        id: 'leave-balance-test',
        requesterId: staffSession.ownerKey,
        requesterName: staffSession.userName,
        requesterRole: staffSession.role,
        category: leave_model.LeaveCategory.cuti,
        compensationOption:
            leave_model.LeaveCompensationOption.potongSaldoCuti,
        startAt: DateTime(2026, 5, 1),
        endAt: DateTime(2026, 5, 2),
        durationValue: 2,
        reason: 'Test saldo cuti',
        delegateTo: 'Backup',
        status: leave_model.WorkflowStatus.pending,
        approvalSteps: _approvalStepsForStaff(staffSession),
        submittedAt: DateTime(2026, 4, 28, 9),
      ),
    );

    expect(controller.leaveBalanceDaysForSession(staffSession), initialBalance - 2);

    await controller.rejectLeaveRequest(
      spvSession,
      requestId: 'leave-balance-test',
      note: 'Ditolak untuk tes saldo',
    );

    expect(controller.leaveBalanceDaysForSession(staffSession), initialBalance);
  });

  test('leave and wfa submissions appear in spv and management approval lists', () async {
    final controller = AppController(seedWorkflowDemoData: false);
    final staffSession = AppSession.mock(AppRole.staff);
    final spvSession = AppSession.mock(AppRole.spv);
    final managementSession = AppSession.mock(AppRole.management);

    await controller.submitLeaveRequest(
      staffSession,
      leave_model.LeaveRequestRecord(
        id: 'leave-approval-flow-test',
        requesterId: staffSession.ownerKey,
        requesterName: staffSession.userName,
        requesterRole: staffSession.role,
        category: leave_model.LeaveCategory.izinPerHari,
        compensationOption:
            leave_model.LeaveCompensationOption.tidakPotongGaji,
        startAt: DateTime(2026, 5, 3),
        endAt: DateTime(2026, 5, 3),
        durationValue: 1,
        reason: 'Test approval leave',
        delegateTo: 'Backup',
        status: leave_model.WorkflowStatus.pending,
        approvalSteps: _approvalStepsForStaff(staffSession),
        submittedAt: DateTime(2026, 4, 28, 9),
      ),
    );

    await controller.submitWfaRequest(
      staffSession,
      wfa_model.WfaRequestRecord(
        id: 'wfa-approval-flow-test',
        requesterId: staffSession.ownerKey,
        requesterName: staffSession.userName,
        requesterRole: staffSession.role,
        mode: wfa_model.WfaRequestMode.regular,
        compensationMode: wfa_model.WfaCompensationMode.normalShift,
        workDate: DateTime(2026, 5, 4),
        startTime: '08:30',
        endTime: '17:00',
        locationLabel: 'Rumah',
        reason: 'Test approval WFA',
        initialTask: 'Validasi task',
        status: wfa_model.WorkflowStatus.pending,
        approvalSteps: _approvalStepsForStaff(staffSession),
        taskUpdates: const [],
        submittedAt: DateTime(2026, 4, 28, 9),
      ),
    );

    final spvLeaveInbox = controller.leaveApprovalsForSession(spvSession);
    final spvWfaInbox = controller.wfaApprovalsForSession(spvSession);

    expect(
      spvLeaveInbox.any((item) => item.id == 'leave-approval-flow-test'),
      isTrue,
    );
    expect(
      spvWfaInbox.any((item) => item.id == 'wfa-approval-flow-test'),
      isTrue,
    );

    await controller.approveLeaveRequest(
      spvSession,
      requestId: 'leave-approval-flow-test',
      note: 'SPV approve',
    );
    await controller.approveWfaRequest(
      spvSession,
      requestId: 'wfa-approval-flow-test',
      note: 'SPV approve',
    );

    final managementLeaveInbox = controller.leaveApprovalsForSession(
      managementSession,
    );
    final managementWfaInbox = controller.wfaApprovalsForSession(
      managementSession,
    );

    expect(
      managementLeaveInbox.any((item) => item.id == 'leave-approval-flow-test'),
      isTrue,
    );
    expect(
      managementWfaInbox.any((item) => item.id == 'wfa-approval-flow-test'),
      isTrue,
    );
  });

  test('network entry and follow-up are recorded for FGG owner', () async {
    final controller = AppController(seedWorkflowDemoData: false);
    final fggSession = AppSession.mock(AppRole.fgg, userName: 'Tester FGG');

    final entry = NetworkEntry.mock(
      ownerKey: fggSession.ownerKey,
      ownerName: fggSession.userName,
      ownerRole: fggSession.role,
      type: NetworkEntryType.ukm,
      name: 'UKM Test Persist',
      address: 'Cilandak',
      businessType: 'Kuliner',
      phone: '081234567890',
      status: 'Draft',
      statusColor: Colors.teal,
    );

    await controller.upsertNetworkEntryForSession(fggSession, entry);
    await controller.addFollowUpToEntry(
      entry: controller.ownNetworkEntriesForSession(fggSession).first,
      status: 'Follow-up',
      statusColor: Colors.orange,
      followUp: NetworkFollowUp(
        title: 'Kunjungan pertama',
        note: 'Pemilik minta ditindaklanjuti minggu depan.',
        actorName: fggSession.userName,
        createdAt: DateTime(2026, 5, 8, 9, 30),
      ),
    );

    final storedEntries = controller.ownNetworkEntriesForSession(fggSession);
    expect(storedEntries, hasLength(1));
    expect(storedEntries.first.name, 'UKM Test Persist');
    expect(storedEntries.first.followUps, isNotEmpty);
    expect(storedEntries.first.followUps.first.title, 'Kunjungan pertama');
  });

  testWidgets('login form is shown on first launch', (tester) async {
    await tester.pumpWidget(const HexActivityApp());

    expect(find.text('HEX Activity'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Mode demo/dev'), findsOneWidget);
  });

  testWidgets('leave page date picker opens without localization errors', (
    tester,
  ) async {
    final controller = AppController();
    final session = AppSession.mock(AppRole.staff);

    await tester.pumpWidget(
      _TestApp(
        child: LeavePage(
          session: session,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final startDateField = find.byKey(const ValueKey('leave-start-date-input'));
    await tester.ensureVisible(startDateField);
    await tester.tap(startDateField);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wfa page date picker opens without localization errors', (
    tester,
  ) async {
    final controller = AppController();
    final session = AppSession.mock(AppRole.staff);

    await tester.pumpWidget(
      _TestApp(
        child: WfhPage(
          session: session,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final workDateField = find.byKey(const ValueKey('wfa-work-date-input'));
    await tester.ensureVisible(workDateField);
    await tester.tap(workDateField);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

List<ApprovalStep> _approvalStepsForStaff(AppSession session) {
  return [
    ApprovalStep(
      sequence: 1,
      approverRole: AppRole.spv,
      approverId: AppSession.mock(AppRole.spv).ownerKey,
      approverName: session.defaultSpv,
      status: ApprovalStepStatus.pending,
    ),
    ApprovalStep(
      sequence: 2,
      approverRole: AppRole.management,
      approverId: AppSession.mock(AppRole.management).ownerKey,
      approverName: session.defaultManagement,
      status: ApprovalStepStatus.pending,
    ),
  ];
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('id'),
        Locale('en', 'US'),
        Locale('en'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: child),
    );
  }
}
