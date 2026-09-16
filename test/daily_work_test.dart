import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/app/app_controller.dart';
import 'package:folony_activity/core/enums/app_role.dart';
import 'package:folony_activity/core/models/app_session.dart';
import 'package:folony_activity/core/models/daily_work_update.dart';
import 'package:folony_activity/core/repositories/daily_work_repository.dart';
import 'package:folony_activity/features/home/presentation/home_page.dart';
import 'package:folony_activity/features/dashboard/presentation/fgg_dashboard_page.dart';
import 'package:folony_activity/core/repositories/fgg_repository.dart';
import 'package:folony_activity/core/network/simple_api_client.dart';

void main() {
  testWidgets('work status and updates are restored when home is reopened', (tester) async {
    final repository = DailyWorkRepository();
    final session = AppSession.mock(AppRole.staff);
    await repository.save(userId: session.userId, requestId: 'start', note: 'Rencana laporan', isFinished: false);
    final controller = AppController(dailyWorkRepository: repository, seedWorkflowDemoData: false);
    addTearDown(controller.dispose);
    Widget home() => MaterialApp(home: Scaffold(body: HomePage(session: session, controller: controller)));
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();
    expect(find.text('Simpan update'), findsOneWidget);
    expect(find.text('Rencana laporan'), findsNothing);
    await tester.ensureVisible(find.text('Riwayat update'));
    await tester.tap(find.text('Riwayat update'));
    await tester.pumpAndSettle();
    expect(find.text('Rencana laporan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await repository.save(userId: session.userId, requestId: 'finish', note: 'Laporan sudah selesai', isFinished: true);
    await tester.pumpWidget(home());
    await tester.pumpAndSettle();
    expect(find.text('Mulai kerja'), findsOneWidget);
    expect(find.text('Laporan sudah selesai'), findsNothing);
    await tester.ensureVisible(find.text('Riwayat update'));
    await tester.tap(find.text('Riwayat update'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan sudah selesai'), findsOneWidget);
  });

  testWidgets('failed save retains the draft and does not claim success', (tester) async {
    final controller = AppController(dailyWorkRepository: _FailingRepository(), seedWorkflowDemoData: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomePage(
      session: AppSession.mock(AppRole.staff), controller: controller,
    ))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Draft yang belum terkirim');
    await tester.ensureVisible(find.text('Mulai kerja'));
    await tester.tap(find.text('Mulai kerja'));
    await tester.pumpAndSettle();
    expect(find.text('Draft yang belum terkirim'), findsOneWidget);
    expect(find.text('Update pekerjaan hari ini tersimpan.'), findsNothing);
    expect(find.text('Simpan update'), findsNothing);
  });

  testWidgets('FGG home hides daily work while Area Manager keeps it', (tester) async {
    final controller = AppController(seedWorkflowDemoData: false);
    addTearDown(controller.dispose);
    for (final role in [AppRole.fgg, AppRole.areaManager]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: HomePage(
        session: AppSession.mock(role), controller: controller,
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Ingin mengerjakan apa hari ini?'),
          role == AppRole.fgg ? findsNothing : findsOneWidget);
    }
  });

  testWidgets('shipping dashboard loads only for FGG', (tester) async {
    final shipping = _SummaryRepository();
    final controller = AppController(fggRepository: shipping, seedWorkflowDemoData: false);
    addTearDown(controller.dispose);
    for (final role in [AppRole.areaManager, AppRole.fgg]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FieldDashboardPage(
        session: AppSession.mock(role), controller: controller,
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard Kiriman'), role == AppRole.fgg ? findsOneWidget : findsNothing);
      expect(shipping.calls, role == AppRole.fgg ? 1 : 0);
    }
  });
}

class _SummaryRepository extends FggRepository {
  _SummaryRepository() : super(SimpleApiClient(baseUrl: 'https://example.test/api'));
  int calls = 0;
  @override
  Future<Map<String, dynamic>> session() async {
    calls++;
    return {'connected': false};
  }
}

class _FailingRepository extends DailyWorkRepository {
  @override
  Future<DailyWorkUpdate> save({required String userId, required String requestId,
    required String note, required bool isFinished, String? photoUrl}) async {
    throw StateError('Jaringan belum tersedia');
  }
}
