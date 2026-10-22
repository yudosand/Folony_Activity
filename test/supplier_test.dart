import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/app/app_controller.dart';
import 'package:folony_activity/core/enums/app_role.dart';
import 'package:folony_activity/core/network/simple_api_client.dart';
import 'package:folony_activity/core/repositories/supplier_repository.dart';
import 'package:folony_activity/features/shell/presentation/main_shell.dart';
import 'package:folony_activity/features/home/presentation/home_page.dart';
import 'package:folony_activity/features/supplier/presentation/supplier_form_page.dart';
import 'package:folony_activity/features/supplier/presentation/supplier_page.dart';

class SupplierClient extends SimpleApiClient {
  SupplierClient() : super(baseUrl: 'https://example.test/api');
  Map<String, dynamic>? saved;
  final pages = <int>[];

  Map<String, dynamic> record(String id) => {
        'id': id,
        'name': 'Supplier $id',
        'phone_number': '081234567890',
        'territory_province': 'DKI Jakarta',
        'territory_city': 'Jakarta Selatan',
        'territory_district': 'Pasar Minggu',
        'address': 'Jl. Supplier',
        'items': ['Tepung', 'Minyak'],
        'created_by': 'user-1',
        'latitude': null,
        'longitude': null,
      };

  @override
  Future<dynamic> get(String path,
      {Map<String, String>? queryParameters}) async {
    expect(path, '/suppliers');
    expect(queryParameters!.keys, ['page']);
    final page = int.parse(queryParameters['page']!);
    pages.add(page);
    return {
      'data': [record('$page')],
      'meta': {'has_more': page == 1, 'total': 2}
    };
  }

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    expect(path, '/suppliers');
    saved = body;
    return {
      'data': {...record('new'), ...body!}
    };
  }
}

void main() {
  testWidgets(
      'GPS saves without manual regions when address lookup is unavailable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      return switch (call.method) {
        'isLocationServiceEnabled' => true,
        'checkPermission' => 3,
        'getCurrentPosition' => {
            'latitude': -6.2,
            'longitude': 106.8,
            'accuracy': 5.0
          },
        _ => null,
      };
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final client = SupplierClient();
    final controller = AppController(
        supplierRepository: SupplierRepository(client),
        seedWorkflowDemoData: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
        MaterialApp(home: SupplierFormPage(controller: controller)));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    await tester.enterText(field('Nama supplier'), 'Supplier GPS');
    await tester.enterText(field('Nama PIC supplier'), 'Ibu Sari');
    await tester.enterText(field('No. HP'), '081234567890');
    await tester.tap(find.text('Lokasi supplier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gunakan GPS'));
    await tester.pumpAndSettle();
    expect(field('Provinsi'), findsNothing);
    expect(field('Kota/Kabupaten'), findsNothing);
    expect(field('Kecamatan'), findsNothing);
    expect(field('Alamat lengkap'), findsNothing);
    expect(find.text('-6.200000, 106.800000'), findsOneWidget);
    await tester.enterText(field('Barang 1'), 'Beras');
    await tester.ensureVisible(find.text('Simpan Supplier'));
    await tester.tap(find.text('Simpan Supplier'));
    await tester.pumpAndSettle();
    expect(client.saved?['location_source'], 'gps');
    expect(client.saved?['latitude'], -6.2);
    expect(client.saved?['longitude'], 106.8);
    expect(client.saved?['territory_province'], '');
    expect(client.saved?['pic_name'], 'Ibu Sari');
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });

  for (final role in AppRole.values) {
    testWidgets('supplier menus follow role ${role.name}', (tester) async {
      final controller = AppController(seedWorkflowDemoData: false);
      controller.signInAs(role);
      addTearDown(controller.dispose);
      await tester
          .pumpWidget(MaterialApp(home: MainShell(controller: controller)));
      await tester.pumpAndSettle();
      final expected =
          [AppRole.spv, AppRole.management, AppRole.areaManager].contains(role);
      final home = tester.widget<HomePage>(find.byType(HomePage));
      expect(home.homeMenus.any((m) => m.title == 'Tambah Supplier'), expected);
      expect(
          home.homeMenus.any((m) => m.title == 'Supplier yang saya tambahkan'),
          expected);
      if (expected) {
        home.homeMenus.firstWhere((m) => m.title == 'Tambah Supplier').onTap();
        await tester.pumpAndSettle();
        expect(find.byType(SupplierFormPage), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('owned supplier list paginates and opens all details',
      (tester) async {
    final client = SupplierClient();
    final controller = AppController(
        supplierRepository: SupplierRepository(client),
        seedWorkflowDemoData: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SupplierPage(controller: controller))));
    await tester.pumpAndSettle();
    expect(find.text('Supplier 1'), findsOneWidget);
    await tester.tap(find.text('Muat supplier berikutnya'));
    await tester.pumpAndSettle();
    expect(client.pages, [1, 2]);
    expect(find.text('Supplier 2'), findsOneWidget);
    await tester.tap(find.text('Supplier 2'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Supplier'), findsOneWidget);
    expect(find.text('Tepung\nMinyak'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'manual supplier form supports cascading regions and multiple goods without GPS or spoofed PIC',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = SupplierClient();
    final controller = AppController(
        supplierRepository: SupplierRepository(client),
        seedWorkflowDemoData: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
        MaterialApp(home: SupplierFormPage(controller: controller)));
    await tester.pumpAndSettle();
    final expansion = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
    expect(expansion.initiallyExpanded, false);
    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    await tester.enterText(field('Nama supplier'), 'Supplier Uji');
    await tester.enterText(field('Nama PIC supplier'), 'Ibu Sari');
    await tester.enterText(field('No. HP'), '081234567890');
    for (final region in [
      ['Provinsi', 'DKI Jakarta'],
      ['Kota/Kabupaten', 'Jakarta Selatan'],
      ['Kecamatan', 'Pasar Minggu']
    ]) {
      await tester.tap(field(region[0]));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, region[1]));
      await tester.pumpAndSettle();
    }
    await tester.enterText(field('Alamat lengkap'), 'Jalan Contoh 12');
    await tester.enterText(field('Barang 1'), 'Tepung');
    await tester.tap(find.text('Tambah barang'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Barang 2'), 'Minyak');
    await tester.ensureVisible(find.text('Simpan Supplier'));
    await tester.tap(find.text('Simpan Supplier'));
    await tester.pumpAndSettle();
    expect(client.saved?['items'], ['Tepung', 'Minyak']);
    expect(client.saved?['pic_name'], 'Ibu Sari');
    expect(client.saved?['territory_district'], 'Pasar Minggu');
    expect(client.saved?['latitude'], null);
    expect(client.saved?['location_source'], 'manual');
    expect(client.saved?.containsKey('created_by'), false);
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
  });
}
