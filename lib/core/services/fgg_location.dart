import 'package:geolocator/geolocator.dart';

Future<Map<String, dynamic>> captureFggLocation() async {
  try {
    return await _captureFggLocation();
  } on StateError {
    rethrow;
  } catch (_) {
    throw StateError(
        'Lokasi GPS belum tersedia. Periksa izin lokasi dan coba lagi.');
  }
}

Future<Map<String, dynamic>> _captureFggLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('Aktifkan GPS untuk mencatat lokasi transaksi.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw StateError(
        'Izinkan akses lokasi aplikasi sebelum memproses pengiriman.');
  }
  final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20)))
      .catchError((Object error) {
    throw StateError(
        'GPS belum mendapat lokasi terbaru. Coba lagi di tempat terbuka.');
  });
  if (DateTime.now().difference(position.timestamp).inSeconds > 90) {
    throw StateError(
        'Lokasi GPS belum diperbarui. Coba lagi di tempat terbuka.');
  }
  return {
    'latitude': position.latitude,
    'longitude': position.longitude,
    'accuracy_meters': position.accuracy,
    'captured_at': position.timestamp.toUtc().toIso8601String()
  };
}
