import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folony_activity/app/app.dart';
import 'package:folony_activity/app/app_controller.dart';
import 'package:folony_activity/core/enums/app_role.dart';
import 'package:folony_activity/core/models/attendance_record.dart';
import 'package:folony_activity/core/models/approval_step.dart';
import 'package:folony_activity/core/models/app_session.dart';
import 'package:folony_activity/core/models/face_profile.dart';
import 'package:folony_activity/core/models/face_verification_result.dart';
import 'package:folony_activity/core/models/network_entry.dart';
import 'package:folony_activity/core/models/remote_attachment.dart';
import 'package:folony_activity/core/repositories/attendance_repository.dart';
import 'package:folony_activity/core/repositories/face_profile_repository.dart';
import 'package:folony_activity/core/repositories/hybrid/fallback_attendance_repository.dart';
import 'package:folony_activity/core/repositories/hybrid/workflow_repository_mode.dart';
import 'package:folony_activity/core/repositories/upload_repository.dart';
import 'package:folony_activity/features/face/data/face_biometric_analyzer.dart';
import 'package:folony_activity/core/models/leave_request_record.dart'
    as leave_model;
import 'package:folony_activity/core/models/wfa_request_record.dart'
    as wfa_model;
import 'package:folony_activity/features/leave/presentation/leave_page.dart';
import 'package:folony_activity/features/leave/presentation/leave_approval_page.dart';
import 'package:folony_activity/features/wfh/presentation/wfh_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  test('multi-role tester can sign in and switch roles in local mode', () async {
    final controller = AppController(
      useRemoteAuth: false,
      allowDemoMode: true,
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

  test('multi-role tester is blocked in remote mode', () async {
    final controller = AppController(
      useRemoteAuth: true,
      seedWorkflowDemoData: false,
    );

    expect(
      () => controller.signIn(
        identifier: AppController.multiRoleTesterIdentifier,
        password: AppController.multiRoleTesterPassword,
        fallbackRole: AppRole.staff,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Akun allrole hanya tersedia di mode demo lokal'),
        ),
      ),
    );
  });

  test('demo login is blocked when local demo mode is disabled', () async {
    final controller = AppController(
      useRemoteAuth: false,
      allowDemoMode: false,
      seedWorkflowDemoData: false,
    );

    expect(
      () => controller.signIn(
        identifier: 'asal',
        password: '123456',
        fallbackRole: AppRole.staff,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Mode demo tidak aktif'),
        ),
      ),
    );
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

  test(
    'remote attendance writes fail loudly instead of falling back to local data',
    () async {
      final local = _RecordingAttendanceRepository();
      final repository = FallbackAttendanceRepository(
        mode: WorkflowRepositoryMode.remotePreferred,
        remote: _ThrowingAttendanceRepository(),
        local: local,
      );

      final record = AttendanceRecord(
        id: 'att-remote-strict-test',
        userId: 'usr_001',
        workDate: DateTime(2026, 5, 20),
        action: AttendanceAction.checkIn,
        status: AttendanceRecordStatus.pending,
        recordedAt: DateTime(2026, 5, 20, 8, 0),
        location: AttendanceLocationRecord(
          latitude: -6.2,
          longitude: 106.8,
          recordedAt: DateTime(2026, 5, 20, 8, 0),
        ),
      );

      expect(
        () => repository.createRecord(record),
        throwsA(isA<StateError>()),
      );
      expect(local.createdRecords, isEmpty);
    },
  );

  test('face enrollment updates session state without heavy processing', () async {
    final controller = AppController(
      faceProfileRepository: _FakeFaceProfileRepository(),
      uploadRepository: const _FakeUploadRepository(),
      faceBiometricAnalyzer: _FakeFaceBiometricAnalyzer(),
      seedWorkflowDemoData: false,
    );

    controller.signInAs(AppRole.staff, userName: 'Tester Staff');

    final enrolled = await controller.enrollFaceForSession(
      controller.session!,
      samplePaths: const ['sample-1.jpg', 'sample-2.jpg', 'sample-3.jpg'],
    );

    expect(enrolled.isEnrolled, isTrue);
    expect(controller.hasFaceEnrollmentForSession(controller.session!), isTrue);
  });

  testWidgets('login form is shown on first launch', (tester) async {
    final controller = AppController(
      useRemoteAuth: true,
      allowDemoMode: false,
      seedWorkflowDemoData: false,
    );

    await tester.pumpWidget(HexActivityApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('HEX Activity'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Mode demo/dev'), findsNothing);
    expect(
      find.text('Mode staging aktif. Gunakan akun backend yang valid.'),
      findsOneWidget,
    );
  });

  testWidgets('login page hides demo mode when remote auth is enabled', (
    tester,
  ) async {
    final controller = AppController(
      useRemoteAuth: true,
      seedWorkflowDemoData: false,
    );

    await tester.pumpWidget(HexActivityApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Mode demo/dev'), findsNothing);
    expect(
      find.text('Mode staging aktif. Gunakan akun backend yang valid.'),
      findsOneWidget,
    );
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

  testWidgets(
    'date picker stays safe when app controller notifies while dialog is open',
    (tester) async {
      final controller = AppController(seedWorkflowDemoData: false);
      final session = AppSession.mock(AppRole.staff, userName: 'Tester Staff');

      await tester.pumpWidget(
        _TestApp(
          child: LeavePage(
            session: session,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LeavePage), findsOneWidget);

      final startDateField = find.byKey(const ValueKey('leave-start-date-input'));
      await tester.ensureVisible(startDateField);
      await tester.tap(startDateField);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      controller.signInAs(AppRole.staff, userName: 'Tester Staff Update');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'management approval note dialog stays safe when controller notifies',
    (tester) async {
      final controller = AppController(seedWorkflowDemoData: false);
      final spvSession = AppSession.mock(AppRole.spv, userName: 'Bagas SPV');
      final managementSession = AppSession.mock(
        AppRole.management,
        userName: 'Rina Management',
      );

      await controller.submitLeaveRequest(
        spvSession,
        leave_model.LeaveRequestRecord(
          id: 'leave-management-dialog-test',
          requesterId: spvSession.ownerKey,
          requesterName: spvSession.userName,
          requesterRole: spvSession.role,
          category: leave_model.LeaveCategory.cuti,
          compensationOption:
              leave_model.LeaveCompensationOption.potongSaldoCuti,
          startAt: DateTime(2026, 5, 10),
          endAt: DateTime(2026, 5, 10),
          durationValue: 1,
          reason: 'Tes popup approval management',
          delegateTo: 'Backup operasional',
          status: leave_model.WorkflowStatus.pending,
          approvalSteps: [
            ApprovalStep(
              sequence: 1,
              approverRole: AppRole.management,
              approverId: managementSession.ownerKey,
              approverName: managementSession.userName,
              status: ApprovalStepStatus.pending,
            ),
          ],
          submittedAt: DateTime(2026, 5, 9, 9),
        ),
      );

      await tester.pumpWidget(
        _TestApp(
          child: LeaveApprovalPage(
            session: managementSession,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Setujui').first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Approve management');
      controller.signInAs(
        AppRole.management,
        userName: 'Rina Management Update',
      );
      await tester.pump();
      await tester.tap(find.text('Setujui').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'management approval note dialog stays safe inside main shell',
    (tester) async {
      final controller = AppController(seedWorkflowDemoData: false);
      final managementSession = AppSession.mock(
        AppRole.management,
        userName: 'Rina Management',
      );

      controller.signInAs(
        AppRole.management,
        userName: managementSession.userName,
      );

      await controller.submitLeaveRequest(
        AppSession.mock(AppRole.spv, userName: 'Bagas SPV'),
        leave_model.LeaveRequestRecord(
          id: 'leave-management-shell-test',
          requesterId: AppSession.mock(AppRole.spv).ownerKey,
          requesterName: 'Bagas SPV',
          requesterRole: AppRole.spv,
          category: leave_model.LeaveCategory.cuti,
          compensationOption:
              leave_model.LeaveCompensationOption.potongSaldoCuti,
          startAt: DateTime(2026, 5, 10),
          endAt: DateTime(2026, 5, 10),
          durationValue: 1,
          reason: 'Tes popup approval management dari shell',
          delegateTo: 'Backup operasional',
          status: leave_model.WorkflowStatus.pending,
          approvalSteps: [
            ApprovalStep(
              sequence: 1,
              approverRole: AppRole.management,
              approverId: managementSession.ownerKey,
              approverName: managementSession.userName,
              status: ApprovalStepStatus.pending,
            ),
          ],
          submittedAt: DateTime(2026, 5, 9, 9),
        ),
      );

      await tester.pumpWidget(
        HexActivityApp(controller: controller),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approval'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Setujui').first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Approve from shell');
      await tester.tap(find.text('Setujui').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
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

class _ThrowingAttendanceRepository implements AttendanceRepository {
  @override
  Future<void> clearByUser({required String userId}) {
    throw StateError('Remote attendance write failed');
  }

  @override
  Future<AttendanceRecord> createRecord(AttendanceRecord record) {
    throw StateError('Remote attendance write failed');
  }

  @override
  Future<List<AttendanceRecord>> listByUser({
    required String userId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    throw StateError('Remote attendance read failed');
  }

  @override
  Future<AttendanceRecord> latestRecordForToday({required String userId}) {
    throw StateError('Remote attendance read failed');
  }
}

class _RecordingAttendanceRepository implements AttendanceRepository {
  final List<AttendanceRecord> createdRecords = [];

  @override
  Future<void> clearByUser({required String userId}) async {
    createdRecords.removeWhere((record) => record.userId == userId);
  }

  @override
  Future<AttendanceRecord> createRecord(AttendanceRecord record) async {
    createdRecords.add(record);
    return record;
  }

  @override
  Future<List<AttendanceRecord>> listByUser({
    required String userId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    return createdRecords.where((record) => record.userId == userId).toList();
  }

  @override
  Future<AttendanceRecord> latestRecordForToday({required String userId}) async {
    return createdRecords.lastWhere((record) => record.userId == userId);
  }
}

class _FakeFaceProfileRepository implements FaceProfileRepository {
  FaceProfile _profile = FaceProfile.empty(userId: 'usr_001');

  @override
  Future<FaceProfile> currentProfile() async => _profile;

  @override
  Future<FaceProfile> enroll({
    required List<RemoteAttachment> samples,
    required List<double> biometricTemplate,
    String? note,
  }) async {
    _profile = FaceProfile(
      id: 'face-profile-1',
      userId: 'usr_001',
      status: 'active',
      samples: samples,
      samplesCount: samples.length,
      biometricTemplateReady: biometricTemplate.length >= 64,
      enrolledAt: DateTime.now(),
      verificationMode: 'lightweight_signature_v2',
      note: note,
    );
    return _profile;
  }

  @override
  Future<FaceVerificationResult> verify({
    required String action,
    required RemoteAttachment capture,
    required List<double> signature,
    required double livenessScore,
    String? note,
  }) async {
    return FaceVerificationResult(
      verified: _profile.isEnrolled,
      decision: _profile.isEnrolled ? 'verified' : 'rejected',
      matchScore: 100,
      livenessScore: livenessScore,
      capture: capture,
      profile: _profile,
      note: note,
      verifiedAt: DateTime.now(),
    );
  }
}

class _FakeFaceBiometricAnalyzer extends FaceBiometricAnalyzer {
  @override
  Future<FaceBiometricTemplate> buildEnrollmentTemplate(
    List<String> samplePaths,
  ) async {
    return FaceBiometricTemplate(
      template: List<double>.filled(128, 0.088388),
      samplesCount: samplePaths.length,
    );
  }

  @override
  Future<FaceBiometricCapture> analyzeCapture(String imagePath) async {
    return FaceBiometricCapture(
      signature: List<double>.filled(128, 0.088388),
    );
  }
}

class _FakeUploadRepository implements UploadRepository {
  const _FakeUploadRepository();

  @override
  Future<RemoteAttachment> uploadAttachment({
    required String filePath,
    String? label,
  }) async {
    return RemoteAttachment(
      id: filePath,
      fileName: label ?? filePath,
      mimeType: 'image/jpeg',
      url: 'https://mock.local/$filePath',
      thumbnailUrl: 'https://mock.local/$filePath-thumb',
      sizeInBytes: 1024,
    );
  }
}
