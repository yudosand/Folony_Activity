import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:folony_activity/features/fgg/presentation/fgg_summary_card.dart';
import 'package:folony_activity/core/network/simple_api_client.dart';
import 'package:folony_activity/core/repositories/fgg_repository.dart';

class RecordingClient extends SimpleApiClient {
  RecordingClient() : super(baseUrl: 'https://example.test/api');
  Map<String, dynamic>? body;
  String? path;
  final pages = <String>[];
  bool failSecond = false;
  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    this.path = path;
    this.body = body;
    return {'message': 'ok'};
  }

  @override
  Future<dynamic> get(String path,
      {Map<String, String>? queryParameters}) async {
    if (path == '/fgg/session')
      return {
        'data': {'connected': true, 'hub_id': 'HUB12'}
      };
    final status = queryParameters!['status']!;
    final page = int.parse(queryParameters['pagination']!);
    pages.add('$status:$page');
    if (failSecond && page == 2) throw StateError('offline');
    return {
      'page': page,
      'total_pages': status == '2' ? 3 : 1,
      'data': [
        {'transaction_id': '$status-$page-A'},
        {'transaction_id': '$status-$page-B'}
      ]
    };
  }
}

void main() {
  testWidgets('dashboard displays complete shipment totals', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                FggSummaryCard(repository: FggRepository(RecordingClient())))));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard Kiriman'), findsOneWidget);
    expect(find.text('Belum dikirim'), findsOneWidget);
    expect(find.text('Sudah dikirim'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });
  test('counts every history page, not totalPage or first-page row count',
      () async {
    final client = RecordingClient();
    final result = await FggRepository(client).shippingSummary();
    expect(result, {'pending': 2, 'sent': 6});
    expect(client.pages, ['1:1', '2:1', '2:2', '2:3']);
  });
  test('partial history failure never returns a misleading total', () async {
    final client = RecordingClient()..failSecond = true;
    await expectLater(
        FggRepository(client).shippingSummary(), throwsStateError);
  });
  test('GPS is refreshed for each receive/send and sent with action payload',
      () async {
    final client = RecordingClient();
    var captures = 0;
    final repo = FggRepository(client, locationProvider: () async {
      captures++;
      return {
        'latitude': -6.2,
        'longitude': 106.8,
        'accuracy_meters': captures,
        'captured_at': DateTime.now().toUtc().toIso8601String()
      };
    });
    await repo.receive('360');
    expect(client.path, '/fgg/actions/receive');
    expect(client.body!['accuracy_meters'], 1);
    await repo.send('7163', 'photo');
    expect(client.path, '/fgg/actions/send');
    expect(client.body!['accuracy_meters'], 2);
    expect(client.body!['buktiFoto'], 'photo');
  });
  test('GPS failure does not submit shipment', () async {
    final client = RecordingClient();
    final repo = FggRepository(client,
        locationProvider: () async => throw StateError('GPS disabled'));
    await expectLater(repo.receive('360'), throwsStateError);
    expect(client.path, isNull);
  });
}
