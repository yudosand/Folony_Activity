import '../network/simple_api_client.dart';

class BusinessKindOption {
  const BusinessKindOption({required this.id, required this.name});
  final String id;
  final String name;
}

class BusinessCategoryOption {
  const BusinessCategoryOption(
      {required this.id, required this.name, required this.kinds});
  final String id;
  final String name;
  final List<BusinessKindOption> kinds;
}

class BusinessCatalogRepository {
  const BusinessCatalogRepository(this.client);
  final SimpleApiClient client;
  Future<List<BusinessCategoryOption>> load() async {
    final result = await client.get('/business-catalog');
    return (result['data'] as List)
        .map((c) => BusinessCategoryOption(
              id: c['id'] as String,
              name: c['name'] as String,
              kinds: (c['kinds'] as List)
                  .map((k) => BusinessKindOption(
                      id: k['id'] as String, name: k['name'] as String))
                  .toList(),
            ))
        .toList();
  }
}
