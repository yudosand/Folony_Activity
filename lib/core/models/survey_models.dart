import 'remote_attachment.dart';

class SurveyChoiceOption {
  const SurveyChoiceOption({
    required this.id,
    required this.name,
    this.unit,
  });

  final String id;
  final String name;
  final String? unit;

  factory SurveyChoiceOption.fromJson(Map<String, dynamic> json) {
    return SurveyChoiceOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String?,
    );
  }
}

class SurveyOptions {
  const SurveyOptions({
    required this.products,
    required this.commodities,
    required this.buildingTypes,
    required this.kioskSizes,
  });

  final List<SurveyChoiceOption> products;
  final List<SurveyChoiceOption> commodities;
  final List<String> buildingTypes;
  final List<String> kioskSizes;

  static const fallback = SurveyOptions(
    products: [
      SurveyChoiceOption(id: 'beras', name: 'Beras'),
      SurveyChoiceOption(id: 'minyak', name: 'Minyak goreng'),
      SurveyChoiceOption(id: 'gula', name: 'Gula'),
      SurveyChoiceOption(id: 'telur', name: 'Telur'),
    ],
    commodities: [
      SurveyChoiceOption(id: 'beras-medium', name: 'Beras medium', unit: 'kg'),
      SurveyChoiceOption(id: 'gula-pasir', name: 'Gula pasir', unit: 'kg'),
      SurveyChoiceOption(
          id: 'minyak-goreng', name: 'Minyak goreng', unit: 'liter'),
      SurveyChoiceOption(id: 'telur-ayam', name: 'Telur ayam', unit: 'kg'),
    ],
    buildingTypes: [
      'Permanen',
      'Semi permanen',
      'Non permanen',
      'Ruko',
      'Lapak terbuka',
    ],
    kioskSizes: [
      'Kurang dari 5 meter',
      '5 - 10 Meter',
      '10 - 15 Meter',
    ],
  );

  factory SurveyOptions.fromJson(Map<String, dynamic> json) {
    return SurveyOptions(
      products: _optionsFrom(json['products']),
      commodities: _optionsFrom(json['commodities']),
      buildingTypes: _stringsFrom(json['building_types']),
      kioskSizes: _stringsFrom(json['kiosk_sizes']),
    );
  }

  static List<SurveyChoiceOption> _optionsFrom(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => SurveyChoiceOption.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
        .toList();
  }

  static List<String> _stringsFrom(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value.map((item) => item.toString()).where((item) {
      return item.trim().isNotEmpty;
    }).toList();
  }
}

class KioskSurveySubmission {
  const KioskSurveySubmission({
    required this.photo,
    required this.latitude,
    required this.longitude,
    required this.kioskName,
    required this.kioskAddress,
    required this.phoneNumber,
    required this.ownerName,
    required this.productIds,
    required this.otherProduct,
    required this.buildingTypes,
    required this.kioskSizes,
    this.locationAccuracyMeters,
    this.territoryProvince = '',
    this.territoryCity = '',
    this.territoryDistrict = '',
    this.territorySubdistrict = '',
    this.locationAddress = '',
  });

  final RemoteAttachment photo;
  final double latitude;
  final double longitude;
  final double? locationAccuracyMeters;
  final String territoryProvince;
  final String territoryCity;
  final String territoryDistrict;
  final String territorySubdistrict;
  final String locationAddress;
  final String kioskName;
  final String kioskAddress;
  final String phoneNumber;
  final String ownerName;
  final List<String> productIds;
  final String otherProduct;
  final List<String> buildingTypes;
  final List<String> kioskSizes;

  Map<String, dynamic> toJson() {
    return {
      'photo': photo.toJson(),
      'territory_province': territoryProvince,
      'territory_city': territoryCity,
      'territory_district': territoryDistrict,
      'territory_subdistrict': territorySubdistrict,
      'latitude': latitude,
      'longitude': longitude,
      'location_accuracy_meters': locationAccuracyMeters,
      'location_address': locationAddress,
      'kiosk_name': kioskName,
      'kiosk_address': kioskAddress,
      'phone_number': phoneNumber,
      'owner_name': ownerName,
      'product_ids': productIds,
      'other_product': otherProduct,
      'building_types': buildingTypes,
      'kiosk_sizes': kioskSizes,
    };
  }
}

class CommodityPriceSubmission {
  const CommodityPriceSubmission({
    required this.commodityId,
    required this.commodityName,
    required this.lowestPrice,
    required this.highestPrice,
    this.unit,
  });

  final String commodityId;
  final String commodityName;
  final double lowestPrice;
  final double highestPrice;
  final String? unit;

  Map<String, dynamic> toJson() {
    return {
      'commodity_id': commodityId,
      'commodity_name': commodityName,
      'unit': unit,
      'lowest_price': lowestPrice,
      'highest_price': highestPrice,
    };
  }
}

class PriceSurveySubmission {
  const PriceSurveySubmission({
    required this.photo,
    required this.marketName,
    required this.latitude,
    required this.longitude,
    required this.commodityPrices,
    this.locationAccuracyMeters,
    this.territoryProvince = '',
    this.territoryCity = '',
    this.territoryDistrict = '',
    this.territorySubdistrict = '',
    this.locationAddress = '',
  });

  final RemoteAttachment photo;
  final String marketName;
  final double latitude;
  final double longitude;
  final double? locationAccuracyMeters;
  final String territoryProvince;
  final String territoryCity;
  final String territoryDistrict;
  final String territorySubdistrict;
  final String locationAddress;
  final List<CommodityPriceSubmission> commodityPrices;

  Map<String, dynamic> toJson() {
    return {
      'photo': photo.toJson(),
      'market_name': marketName,
      'territory_province': territoryProvince,
      'territory_city': territoryCity,
      'territory_district': territoryDistrict,
      'territory_subdistrict': territorySubdistrict,
      'latitude': latitude,
      'longitude': longitude,
      'location_accuracy_meters': locationAccuracyMeters,
      'location_address': locationAddress,
      'commodity_prices': commodityPrices.map((item) => item.toJson()).toList(),
    };
  }
}
