class HeatMapUserLocation {
  const HeatMapUserLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  factory HeatMapUserLocation.fromJson(Map<String, dynamic> json) {
    return HeatMapUserLocation(
      latitude: _doubleFromJson(json['latitude']) ?? 0,
      longitude: _doubleFromJson(json['longitude']) ?? 0,
      recordedAt: _dateTimeFromJson(json['recorded_at']),
    );
  }
}

class HeatMapPoint {
  const HeatMapPoint({
    required this.id,
    required this.type,
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.status,
    required this.note,
    required this.distanceMeter,
    required this.latitude,
    required this.longitude,
    required this.ownerName,
  });

  final String id;
  final String type;
  final String name;
  final String address;
  final String phoneNumber;
  final String status;
  final String? note;
  final int distanceMeter;
  final double latitude;
  final double longitude;
  final String ownerName;

  factory HeatMapPoint.fromJson(Map<String, dynamic> json) {
    return HeatMapPoint(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'ukm',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      status: json['status'] as String? ?? '',
      note: json['note'] as String?,
      distanceMeter: _intFromJson(json['distance_meter']) ?? 0,
      latitude: _doubleFromJson(json['latitude']) ?? 0,
      longitude: _doubleFromJson(json['longitude']) ?? 0,
      ownerName: json['owner_name'] as String? ?? '',
    );
  }
}

class HeatMapSnapshot {
  const HeatMapSnapshot({
    required this.userLocation,
    required this.radiusMeters,
    required this.points,
  });

  final HeatMapUserLocation userLocation;
  final int radiusMeters;
  final List<HeatMapPoint> points;

  factory HeatMapSnapshot.fromJson(Map<String, dynamic> json) {
    return HeatMapSnapshot(
      userLocation: HeatMapUserLocation.fromJson(
        json['user_location'] as Map<String, dynamic>? ?? const {},
      ),
      radiusMeters: _intFromJson(json['radius_meters']) ?? 0,
      points: _pointsFromJson(json['points']),
    );
  }
}

DateTime _dateTimeFromJson(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

List<HeatMapPoint> _pointsFromJson(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(HeatMapPoint.fromJson)
        .toList();
  }
  return const [];
}

double? _doubleFromJson(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String && value.trim().isNotEmpty) {
    return double.tryParse(value.trim());
  }
  return null;
}

int? _intFromJson(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String && value.trim().isNotEmpty) {
    return int.tryParse(value.trim());
  }
  return null;
}
