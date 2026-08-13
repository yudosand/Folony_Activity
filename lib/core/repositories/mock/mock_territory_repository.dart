import '../../models/territory_option.dart';
import '../territory_repository.dart';

class MockTerritoryRepository implements TerritoryRepository {
  const MockTerritoryRepository();

  static const _provinces = [
    TerritoryOption(code: '31', name: 'DKI Jakarta'),
    TerritoryOption(code: '32', name: 'Jawa Barat'),
  ];

  static const _cities = [
    TerritoryOption(
      code: '3174',
      name: 'Jakarta Barat',
      provinceCode: '31',
      provinceName: 'DKI Jakarta',
    ),
    TerritoryOption(
      code: '3173',
      name: 'Jakarta Selatan',
      provinceCode: '31',
      provinceName: 'DKI Jakarta',
    ),
  ];

  static const _districts = [
    TerritoryOption(
      code: '3174010',
      name: 'Grogol Petamburan',
      provinceCode: '31',
      provinceName: 'DKI Jakarta',
      cityCode: '3174',
      cityName: 'Jakarta Barat',
    ),
    TerritoryOption(
      code: '3173020',
      name: 'Pasar Minggu',
      provinceCode: '31',
      provinceName: 'DKI Jakarta',
      cityCode: '3173',
      cityName: 'Jakarta Selatan',
    ),
  ];

  static const _subdistricts = [
    TerritoryOption(
      code: '3174010001',
      name: 'Grogol',
      provinceCode: '31',
      provinceName: 'DKI Jakarta',
      cityCode: '3174',
      cityName: 'Jakarta Barat',
      districtCode: '3174010',
      districtName: 'Grogol Petamburan',
    ),
    TerritoryOption(
      code: '3174010002',
      name: 'Tanjung Duren Utara',
      provinceCode: '31',
      provinceName: 'DKI Jakarta',
      cityCode: '3174',
      cityName: 'Jakarta Barat',
      districtCode: '3174010',
      districtName: 'Grogol Petamburan',
    ),
    TerritoryOption(
      code: '3173020001',
      name: 'Pejaten Timur',
      provinceCode: '31',
      provinceName: 'DKI Jakarta',
      cityCode: '3173',
      cityName: 'Jakarta Selatan',
      districtCode: '3173020',
      districtName: 'Pasar Minggu',
    ),
  ];

  @override
  Future<List<TerritoryOption>> listProvinces() async => _provinces;

  @override
  Future<List<TerritoryOption>> listCities(
      {required String provinceCode}) async {
    return _cities.where((item) => item.provinceCode == provinceCode).toList();
  }

  @override
  Future<List<TerritoryOption>> listDistricts(
      {required String cityCode}) async {
    return _districts.where((item) => item.cityCode == cityCode).toList();
  }

  @override
  Future<List<TerritoryOption>> listSubdistricts({
    required String districtCode,
  }) async {
    return _subdistricts
        .where((item) => item.districtCode == districtCode)
        .toList();
  }
}
