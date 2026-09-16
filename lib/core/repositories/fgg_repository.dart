import '../network/simple_api_client.dart';
import '../services/fgg_location.dart';
import 'package:flutter/foundation.dart';

class FggRepository extends ChangeNotifier {
  FggRepository(this.client,
      {Future<Map<String, dynamic>> Function()? locationProvider})
      : _locationProvider = locationProvider ?? captureFggLocation;
  final SimpleApiClient client;
  final Future<Map<String, dynamic>> Function() _locationProvider;

  Future<Map<String, int>> shippingSummary() async {
    Future<int> count(int status) async {
      final ids = <String>{};
      var pages = 1;
      for (var page = 1; page <= pages; page++) {
        final result = await list('shipments', status: status, page: page);
        pages = (result['total_pages'] as num).toInt();
        if (pages > 5000 || (pages > 0 && result['page'] != page)) {
          throw StateError(
              'Riwayat kiriman belum dapat dihitung lengkap. Coba muat ulang.');
        }
        final rows = result['data'] as List;
        final before = ids.length;
        for (final row in rows) {
          final id = row['transaction_id'];
          if (id == null) {
            throw StateError('Data riwayat kiriman tidak lengkap.');
          }
          ids.add(id.toString());
        }
        if (page > 1 && ids.length == before && rows.isNotEmpty) {
          throw StateError(
              'Halaman riwayat berulang. Jumlah belum dapat dipastikan.');
        }
      }
      return ids.length;
    }

    final pending = await count(1);
    final sent = await count(2);
    return {'pending': pending, 'sent': sent};
  }

  Future<Map<String, dynamic>> session() async =>
      Map<String, dynamic>.from((await client.get('/fgg/session'))['data']);

  Future<Map<String, dynamic>> connect(Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(
          (await client.post('/fgg/connect', body: data))['data']);

  Future<Map<String, dynamic>> selectHub(String id) async {
    final result = Map<String, dynamic>.from(
        (await client.post('/fgg/hub', body: {'hub_id': id}))['data']);
    notifyListeners();
    return result;
  }

  Future<void> disconnect() async {
    await client.delete('/fgg/session');
    notifyListeners();
  }

  Future<Map<String, dynamic>> list(String kind,
          {String search = '', int status = 0, int page = 1}) async =>
      Map<String, dynamic>.from(
          await client.get('/fgg/list/$kind', queryParameters: {
        'search': search,
        'status': '$status',
        'pagination': '$page',
        if (kind == 'dst') 'location': '',
      }));

  Future<dynamic> detail(String kind, String id) async => (await client
      .get('/fgg/detail/$kind/${Uri.encodeComponent(id)}'))['data'];

  Future<void> receive(String id) async {
    final location = await _locationProvider();
    await client
        .post('/fgg/actions/receive', body: {'no_dst': id, ...location});
    notifyListeners();
  }

  Future<Map<String, dynamic>?> trip(String id, {String? action}) async {
    final response = action == null
        ? await client.get('/fgg/trips/${Uri.encodeComponent(id)}')
        : await client.post('/fgg/trips/${Uri.encodeComponent(id)}', body: {
            'action': action,
            ...await _locationProvider(),
          });
    return response['data'] == null
        ? null
        : Map<String, dynamic>.from(response['data']);
  }

  Future<void> send(String id, String photo) async {
    final location = await _locationProvider();
    await client.post('/fgg/actions/send',
        body: {'transaction_id': id, 'buktiFoto': photo, ...location});
    notifyListeners();
  }
}
