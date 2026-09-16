import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/core/network/simple_api_client.dart';
import 'package:folony_activity/core/repositories/fgg_repository.dart';
import 'package:folony_activity/features/fgg/presentation/fgg_trip_panel.dart';

class TripRepository extends FggRepository {
  TripRepository() : super(SimpleApiClient(baseUrl: 'https://example.test'));
  Map<String, dynamic>? saved;
  final actions = <String>[];
  @override
  Future<Map<String, dynamic>?> trip(String id, {String? action}) async {
    if (action != null) actions.add(action);
    if (action == 'start')
      saved ??= {
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'destination_address':
            'Bakso Wafa (0812345678001) Jl. A & B No. 12, Jakarta'
      };
    if (action == 'arrive')
      saved = {
        ...saved!,
        'arrived_at': DateTime.now().toUtc().toIso8601String(),
        'duration_seconds': 600
      };
    return saved;
  }
}

void main() {
  testWidgets(
      'directions use order address, reopening does not restart trip and arrival records duration',
      (tester) async {
    final repo = TripRepository();
    final urls = <Uri>[];
    var arrived = false;
    Widget screen() => MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
                    child: FggTripPanel(
          repository: repo,
          orderId: '123',
          canStart: true,
          destination: 'Jl. A & B No. 12, Jakarta',
          onArrived: (value) => arrived = value,
          launchDirections: (uri) async {
            urls.add(uri);
            return true;
          },
        ))));
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai perjalanan & direction'));
    await tester.pumpAndSettle();
    expect(urls.single.queryParameters['destination'],
        'Jl. A & B No. 12, Jakarta');
    expect(urls.single.queryParameters['api'], '1');
    expect(repo.actions, ['start']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.text('Mulai perjalanan & direction'), findsNothing);
    await tester.tap(find.text('Buka direction'));
    await tester.pumpAndSettle();
    expect(repo.actions, ['start']);
    await tester.tap(find.text('Tiba di tujuan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah tiba'));
    await tester.pumpAndSettle();
    expect(arrived, isTrue);
    expect(find.text('Durasi perjalanan: 00:10:00'), findsOneWidget);
    expect(repo.actions, ['start', 'arrive']);
    await tester.pumpWidget(const SizedBox());
  });
}
