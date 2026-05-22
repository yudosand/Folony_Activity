class TerritoryOption {
  const TerritoryOption({
    required this.code,
    required this.name,
    this.provinceCode,
    this.provinceName,
    this.cityCode,
    this.cityName,
    this.districtCode,
    this.districtName,
  });

  final String code;
  final String name;
  final String? provinceCode;
  final String? provinceName;
  final String? cityCode;
  final String? cityName;
  final String? districtCode;
  final String? districtName;

  factory TerritoryOption.fromJson(Map<String, dynamic> json) {
    return TerritoryOption(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      provinceCode: json['province_code'] as String?,
      provinceName: json['province_name'] as String?,
      cityCode: json['city_code'] as String?,
      cityName: json['city_name'] as String?,
      districtCode: json['district_code'] as String?,
      districtName: json['district_name'] as String?,
    );
  }
}
