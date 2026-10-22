class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.province,
    required this.city,
    required this.district,
    required this.address,
    required this.items,
    required this.createdBy,
    this.notes,
    this.picName,
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  final String id,
      name,
      phoneNumber,
      province,
      city,
      district,
      address,
      createdBy;
  final List<String> items;
  final String? notes;
  final String? picName;
  final double? latitude, longitude;
  final DateTime? createdAt;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'].toString(),
        name: json['name'] as String,
        picName: json['pic_name'] as String?,
        phoneNumber: json['phone_number'] as String,
        province: json['territory_province'] as String? ?? '',
        city: json['territory_city'] as String? ?? '',
        district: json['territory_district'] as String? ?? '',
        address: json['address'] as String? ?? '',
        items: List<String>.from(json['items'] as List),
        createdBy: json['created_by'].toString(),
        notes: json['notes'] as String?,
        latitude: double.tryParse('${json['latitude']}'),
        longitude: double.tryParse('${json['longitude']}'),
        createdAt: DateTime.tryParse('${json['created_at']}'),
      );
}

class SupplierPageResult {
  const SupplierPageResult(
      {required this.items, required this.hasMore, required this.total});
  final List<Supplier> items;
  final bool hasMore;
  final int total;
}
