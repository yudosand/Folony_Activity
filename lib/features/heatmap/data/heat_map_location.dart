import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class HeatMapCoordinate {
  const HeatMapCoordinate({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

bool isUsableHeatMapLocation({
  required double latitude,
  required double longitude,
  required double accuracy,
  required Duration age,
}) =>
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180 &&
    accuracy.isFinite &&
    accuracy >= 0 &&
    accuracy <= 2000 &&
    age.abs() <= const Duration(minutes: 10);

Future<HeatMapCoordinate> firstHeatMapLocation(
  List<Future<HeatMapCoordinate?>> sources, {
  Duration timeout = const Duration(seconds: 9),
}) {
  final result = Completer<HeatMapCoordinate>();
  var remaining = sources.length;
  for (final source in sources) {
    source.then((coordinate) {
      if (coordinate != null && !result.isCompleted) {
        result.complete(coordinate);
      }
    }, onError: (Object _) {
      // One unavailable provider must not discard another provider's valid fix.
    }).whenComplete(() {
      remaining--;
      if (remaining == 0 && !result.isCompleted) {
        result.completeError(TimeoutException('Lokasi belum terbaca.'));
      }
    });
  }
  return result.future.timeout(timeout);
}

class HeatMapLocation {
  static const _channel = MethodChannel('folony_activity/device_location');

  static LocationSettings get settings => Platform.isAndroid
      ? AndroidSettings(
          forceLocationManager: true,
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
          timeLimit: const Duration(seconds: 8))
      : const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
          timeLimit: Duration(seconds: 8));

  static HeatMapCoordinate? fromPosition(Position? position) {
    if (position == null ||
        !isUsableHeatMapLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          age: DateTime.now().difference(position.timestamp),
        )) {
      return null;
    }
    return HeatMapCoordinate(
        latitude: position.latitude, longitude: position.longitude);
  }

  static Future<HeatMapCoordinate> resolve() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Izin lokasi belum diberikan.');
    }
    if (!await Geolocator.isLocationServiceEnabled()
        .timeout(const Duration(seconds: 3), onTimeout: () => true)) {
      throw StateError('GPS belum aktif.');
    }
    return firstHeatMapLocation([
      _native(),
      Geolocator.getLastKnownPosition().then(fromPosition),
      Geolocator.getCurrentPosition(locationSettings: settings)
          .then(fromPosition),
    ]);
  }

  static Future<HeatMapCoordinate?> _native() async {
    if (!Platform.isAndroid) return null;
    final data = await _channel
        .invokeMapMethod<String, dynamic>('lastKnownLocation')
        .timeout(const Duration(seconds: 8));
    if (data == null) return null;
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    final accuracy = (data['accuracy'] as num?)?.toDouble();
    final age = (data['age_ms'] as num?)?.toInt();
    if (latitude == null ||
        longitude == null ||
        accuracy == null ||
        age == null ||
        !isUsableHeatMapLocation(
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            age: Duration(milliseconds: age))) {
      return null;
    }
    return HeatMapCoordinate(latitude: latitude, longitude: longitude);
  }
}
