import '../models/supplier.dart';
import '../network/simple_api_client.dart';

class SupplierRepository {
  const SupplierRepository(this.client);
  final SimpleApiClient client;

  Future<SupplierPageResult> list({int page = 1}) async {
    final result = Map<String, dynamic>.from(await client
        .get('/suppliers', queryParameters: {'page': '$page'}) as Map);
    final meta = Map<String, dynamic>.from(result['meta'] as Map);
    return SupplierPageResult(
      items: (result['data'] as List)
          .map((e) => Supplier.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hasMore: meta['has_more'] == true,
      total: (meta['total'] as num).toInt(),
    );
  }

  Future<Supplier> create(Map<String, dynamic> data) async {
    final result = await client.post('/suppliers', body: data);
    return Supplier.fromJson(Map<String, dynamic>.from(result['data'] as Map));
  }
}
