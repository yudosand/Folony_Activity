import '../../models/territory_option.dart';
import '../../network/simple_api_client.dart';
import '../territory_repository.dart';

class RemoteTerritoryRepository implements TerritoryRepository {
  const RemoteTerritoryRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<List<TerritoryOption>> listProvinces() async {
    final response = await _client.get('/territories/provinces');
    return _decodeList(response);
  }

  @override
  Future<List<TerritoryOption>> listCities({required String provinceCode}) async {
    final response = await _client.get(
      '/territories/cities',
      queryParameters: {'province_code': provinceCode},
    );
    return _decodeList(response);
  }

  @override
  Future<List<TerritoryOption>> listDistricts({required String cityCode}) async {
    final response = await _client.get(
      '/territories/districts',
      queryParameters: {'city_code': cityCode},
    );
    return _decodeList(response);
  }

  @override
  Future<List<TerritoryOption>> listSubdistricts({
    required String districtCode,
  }) async {
    final response = await _client.get(
      '/territories/subdistricts',
      queryParameters: {'district_code': districtCode},
    );
    return _decodeList(response);
  }

  List<TerritoryOption> _decodeList(dynamic response) {
    if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map>()
          .map((item) => TerritoryOption.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return const [];
  }
}
