import '../../models/heat_map_snapshot.dart';
import '../heat_map_repository.dart';

class MockHeatMapRepository implements HeatMapRepository {
  const MockHeatMapRepository();

  static const List<HeatMapPoint> _allPoints = [
    HeatMapPoint(
      id: 'mock_mitra_001',
      type: 'mitra',
      name: 'Mitra Hub Budi Jaya',
      address: 'Jl. Jagakarsa Raya No. 18',
      phoneNumber: '081298765432',
      status: 'followUp',
      note: 'Perlu update dokumen dan validasi lokasi ulang.',
      distanceMeter: 420,
      latitude: -6.3707,
      longitude: 106.8332,
      ownerName: 'Raka Area Manager',
    ),
    HeatMapPoint(
      id: 'mock_ukm_001',
      type: 'ukm',
      name: 'UKM Toko Harapan',
      address: 'Pasar Minggu Blok A',
      phoneNumber: '081234567890',
      status: 'followUp',
      note: 'Terakhir dikunjungi 3 hari lalu.',
      distanceMeter: 760,
      latitude: -6.3674,
      longitude: 106.8294,
      ownerName: 'Bima FGG',
    ),
    HeatMapPoint(
      id: 'mock_ukm_002',
      type: 'ukm',
      name: 'UKM Ardi Jaya',
      address: 'Kelapa Dua, Depok',
      phoneNumber: '082112223333',
      status: 'completed',
      note: 'Perlu validasi usaha dan jadwal kunjungan berikutnya.',
      distanceMeter: 1450,
      latitude: -6.3612,
      longitude: 106.8244,
      ownerName: 'Bima FGG',
    ),
  ];

  @override
  Future<HeatMapSnapshot> load({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? type,
  }) async {
    final filtered = _allPoints.where((point) {
      if (type != null && point.type != type) {
        return false;
      }
      return point.distanceMeter <= radiusMeters;
    }).toList()
      ..sort((a, b) => a.distanceMeter.compareTo(b.distanceMeter));

    return HeatMapSnapshot(
      userLocation: HeatMapUserLocation(
        latitude: latitude,
        longitude: longitude,
        recordedAt: DateTime.now(),
      ),
      radiusMeters: radiusMeters,
      points: filtered,
    );
  }
}
