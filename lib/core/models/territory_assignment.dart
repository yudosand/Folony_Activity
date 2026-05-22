class TerritoryAssignment {
  const TerritoryAssignment({
    required this.ruleType,
    required this.scope,
    required this.province,
    required this.city,
    required this.district,
    required this.subdistrict,
  });

  final String? ruleType;
  final String? scope;
  final String? province;
  final String? city;
  final String? district;
  final String? subdistrict;

  factory TerritoryAssignment.fromJson(Map<String, dynamic> json) {
    return TerritoryAssignment(
      ruleType: json['rule_type'] as String? ?? 'include',
      scope: json['territory_scope'] as String?,
      province: json['territory_province'] as String?,
      city: json['territory_city'] as String?,
      district: json['territory_district'] as String?,
      subdistrict: json['territory_subdistrict'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rule_type': ruleType,
      'territory_scope': scope,
      'territory_province': province,
      'territory_city': city,
      'territory_district': district,
      'territory_subdistrict': subdistrict,
    };
  }
}
