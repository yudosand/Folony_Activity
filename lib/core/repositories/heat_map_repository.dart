import '../models/heat_map_snapshot.dart';

abstract class HeatMapRepository {
  Future<HeatMapSnapshot> load({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? type,
  });
}
