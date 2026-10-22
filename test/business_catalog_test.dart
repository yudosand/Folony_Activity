import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/core/models/network_profile.dart';
import 'package:folony_activity/core/models/network_profile_mapper.dart';
import 'package:folony_activity/core/network/simple_api_client.dart';
import 'package:folony_activity/core/repositories/business_catalog_repository.dart';
import 'package:folony_activity/features/network/presentation/business_selection_field.dart';

class CatalogClient extends SimpleApiClient {
  CatalogClient() : super(baseUrl: 'https://staging.example/api');
  bool fail = false;
  @override
  Future<dynamic> get(String path,
      {Map<String, String>? queryParameters}) async {
    expect(path, '/business-catalog');
    if (fail) throw StateError('offline');
    return {
      'data': [
        {
          'id': 'food',
          'name': 'Kuliner',
          'kinds': [
            {'id': 'bakso', 'name': 'Bakso'},
            {'id': 'mie', 'name': 'Mie Ayam'}
          ]
        },
        {
          'id': 'shop',
          'name': 'Toko',
          'kinds': [
            {'id': 'kios', 'name': 'Kios'}
          ]
        },
      ]
    };
  }
}

void main() {
  test('classification IDs survive API, UI mapper, copies and save payload',
      () {
    final profile = NetworkProfile.fromJson({
      'id': 'p',
      'business_type': 'Bakso',
      'business_category_id': 'food',
      'business_kind_id': 'bakso'
    });
    final entry = profile.toNetworkEntry().copyWith(name: 'Updated');
    final json = entry.toNetworkProfile().toJson();
    expect(json['business_category_id'], 'food');
    expect(json['business_kind_id'], 'bakso');
    expect(
        NetworkProfile.fromJson({'business_type': 'warung'})
            .toJson()
            .containsKey('business_kind_id'),
        false);
  });
  testWidgets(
      'dependent selections clear old kind and require a compatible new kind',
      (tester) async {
    final client = CatalogClient();
    final form = GlobalKey<FormState>();
    String? category, kind;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
                key: form,
                child: BusinessSelectionField(
                  repository: BusinessCatalogRepository(client),
                  categoryId: 'food',
                  kindId: 'bakso',
                  onChanged: (c, k, n) {
                    category = c;
                    kind = k;
                  },
                )))));
    await tester.pumpAndSettle();
    expect(kind, 'bakso');
    expect(form.currentState!.validate(), true);
    await tester.tap(find.text('Kuliner').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toko').last);
    await tester.pumpAndSettle();
    expect(category, 'shop');
    expect(kind, isNull);
    expect(form.currentState!.validate(), false);
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('Bakso'), findsNothing);
    await tester.tap(find.text('Kios').last);
    await tester.pumpAndSettle();
    expect(kind, 'kios');
    expect(form.currentState!.validate(), true);
  });
  testWidgets(
      'failed catalog cannot submit and can retry without guessing legacy text',
      (tester) async {
    final client = CatalogClient()..fail = true;
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Form(
                key: form,
                child: BusinessSelectionField(
                  repository: BusinessCatalogRepository(client),
                  originalText: 'warung',
                  onChanged: (c, k, n) {},
                )))));
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(form.currentState!.validate(), false);
    client.fail = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsNothing);
    expect(form.currentState!.validate(), false);
  });
}
