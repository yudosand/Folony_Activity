import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/app/app_controller.dart';
import 'package:folony_activity/core/enums/app_role.dart';
import 'package:folony_activity/features/heatmap/presentation/heatmap_page.dart';
import 'package:folony_activity/features/shell/presentation/main_shell.dart';

void main() {
  testWidgets('management can open Heat Map from navigation', (tester) async {
    final controller = AppController(seedWorkflowDemoData: false);
    controller.signInAs(AppRole.management);
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(MaterialApp(home: MainShell(controller: controller)));
    await tester.pumpAndSettle();

    final destination = find.widgetWithText(NavigationDestination, 'Heat Map');
    expect(destination, findsOneWidget);
    await tester.tap(destination);
    await tester.pumpAndSettle();
    expect(find.byType(HeatMapPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
