import '../../models/heat_map_snapshot.dart';
import '../heat_map_repository.dart';

class MockHeatMapRepository implements HeatMapRepository {
  const MockHeatMapRepository();

  @override
  Future<HeatMapSnapshot> load({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? type,
  }) async {
    return HeatMapSnapshot(
      userLocation: HeatMapUserLocation(
        latitude: latitude,
        longitude: longitude,
        recordedAt: DateTime.now(),
      ),
      radiusMeters: radiusMeters,
      points: const [],
    );
  }
}
