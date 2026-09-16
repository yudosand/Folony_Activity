import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:folony_activity/core/network/simple_api_client.dart';
import 'package:folony_activity/core/repositories/fgg_repository.dart';
import 'package:folony_activity/features/fgg/presentation/fgg_shipping_page.dart';

class FakeFggRepository extends FggRepository {
  FakeFggRepository()
      : super(SimpleApiClient(baseUrl: 'https://example.test/api'));
  bool connected = false;
  String? hub;
  int receives = 0;
  bool deny = false;
  List<Map<String, dynamic>> shipments = [];
  final requests = <(String, int, int)>[];
  @override
  Future<Map<String, dynamic>> session() async => {
        'connected': connected,
        'environment': 'staging',
        'hub_id': hub,
        'name': 'Operator',
        'hubs': [
          {'id': 'HUB12', 'name': 'Hub test'}
        ],
      };
  @override
  Future<Map<String, dynamic>> connect(Map<String, dynamic> data) async {
    if (deny) {
      throw ApiException(
          statusCode: 403,
          message: 'Akun ini tidak memiliki role HUB untuk FGG.',
          uri: Uri.parse('https://example.test'));
    }
    connected = true;
    return session();
  }

  @override
  Future<Map<String, dynamic>> selectHub(String id) async {
    hub = id;
    return session();
  }

  @override
  Future<Map<String, dynamic>> list(String kind,
      {String search = '', int status = 0, int page = 1}) async {
    requests.add((kind, status, page));
    return {
      'data': kind == 'dst' && !(status == 1 && receives > 0)
          ? [
              {
                'no_dst': 152,
                'recipient_button': receives == 0,
                'recipient_hub': 'Hub tujuan',
                'list_dpp': [
                  {'no_dpp': 171, 'customer_name': 'Pelanggan'}
                ]
              }
            ]
          : kind == 'shipments'
              ? shipments
              : [],
      'total_pages': 1,
      'page': 1,
    };
  }

  @override
  Future<void> receive(String id) async {
    receives++;
  }

  @override
  Future<dynamic> detail(String kind, String id) async =>
      {'transaction_id': id, 'product': []};
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'Orders_ready exposes delivery with proof while finished orders cannot be sent',
      (tester) async {
    final repo = FakeFggRepository()
      ..connected = true
      ..hub = 'HUB12'
      ..shipments = [
        {'transaction_id': 7297, 'status': 'Orders_ready'},
        {'transaction_id': 5361, 'status': 'finish'},
      ];
    await tester
        .pumpWidget(MaterialApp(home: FggShippingPage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiriman'));
    await tester.pumpAndSettle();
    expect(repo.requests.last, ('shipments', 1, 1));
    expect(find.text('Kirim ke pembeli'), findsOneWidget);
    await tester.ensureVisible(find.text('Kirim ke pembeli'));
    await tester.tap(find.text('Kirim ke pembeli'));
    await tester.pumpAndSettle();
    expect(find.text('Ambil foto bukti'), findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kirim ke pembeli'));
    expect(button.onPressed, isNull);
  });
  testWidgets(
      'requires FGG login and HUB selection then confirms reception once',
      (tester) async {
    final repo = FakeFggRepository();
    await tester
        .pumpWidget(MaterialApp(home: FggShippingPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Hubungkan Akun FGG'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'operator');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Hubungkan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Akun HUB'), findsOneWidget);
    await tester.tap(find.text('Hub test'));
    await tester.pumpAndSettle();
    expect(find.text('DST 152'), findsOneWidget);
    expect(repo.requests.last, ('dst', 1, 1));
    await tester.ensureVisible(find.text('Terima kiriman'));
    await tester.tap(find.text('Terima kiriman'));
    await tester.pumpAndSettle();
    expect(repo.receives, 0);
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();
    expect(repo.receives, 1);
    expect(find.text('Terima kiriman'), findsNothing);
    expect(repo.requests.last, ('shipments', 1, 1));
  });
  testWidgets(
      'DST and shipments open actionable filters and allow viewing history',
      (tester) async {
    final repo = FakeFggRepository()
      ..connected = true
      ..hub = 'HUB12';
    await tester
        .pumpWidget(MaterialApp(home: FggShippingPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(repo.requests.last, ('dst', 1, 1));
    expect(find.widgetWithText(Chip, 'Bisa diterima'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dst-status')));
    await tester.pumpAndSettle();
    repo.receives = 1;
    await tester.tap(find.text('Sudah diterima').last);
    await tester.pumpAndSettle();
    expect(repo.requests.last, ('dst', 2, 1));
    expect(find.widgetWithText(Chip, 'Sudah diterima'), findsOneWidget);
    expect(find.text('Terima kiriman'), findsNothing);
    await tester.tap(find.text('Kiriman'));
    await tester.pumpAndSettle();
    expect(repo.requests.last, ('shipments', 1, 1));
    expect(find.text('Belum ada pesanan yang siap dikirim.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shipments-status')));
    await tester.pumpAndSettle();
    expect(find.text('HUB siap kirim'), findsNothing);
    expect(find.text('Retur'), findsNothing);
    expect(find.text('Semua status'), findsNothing);
    await tester.tap(find.text('Sudah dikirim').last);
    await tester.pumpAndSettle();
    expect(repo.requests.last, ('shipments', 2, 1));
    await tester.tap(find.text('Terima DST'));
    await tester.pumpAndSettle();
    expect(repo.requests.last, ('dst', 1, 1));
  });
  testWidgets(
      'non HUB denial remains inside FGG without affecting Folony session',
      (tester) async {
    final repo = FakeFggRepository()..deny = true;
    await tester
        .pumpWidget(MaterialApp(home: FggShippingPage(repository: repo)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'cohub');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Hubungkan'));
    await tester.pumpAndSettle();
    expect(find.text('Akun ini tidak memiliki role HUB untuk FGG.'),
        findsOneWidget);
    expect(find.text('Hubungkan Akun FGG'), findsOneWidget);
  });
}
