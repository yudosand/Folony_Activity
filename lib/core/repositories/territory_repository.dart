import '../models/territory_option.dart';

abstract class TerritoryRepository {
  Future<List<TerritoryOption>> listProvinces();

  Future<List<TerritoryOption>> listCities({
    required String provinceCode,
  });

  Future<List<TerritoryOption>> listDistricts({
    required String cityCode,
  });

  Future<List<TerritoryOption>> listSubdistricts({
    required String districtCode,
  });
}
