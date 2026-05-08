import '../../models/heat_map_snapshot.dart';
import '../heat_map_repository.dart';
import 'workflow_repository_mode.dart';

class FallbackHeatMapRepository implements HeatMapRepository {
  const FallbackHeatMapRepository({
    required this.mode,
    required HeatMapRepository remote,
    required HeatMapRepository local,
  })  : _remote = remote,
        _local = local;

  final WorkflowRepositoryMode mode;
  final HeatMapRepository _remote;
  final HeatMapRepository _local;

  @override
  Future<HeatMapSnapshot> load({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? type,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.load(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        type: type,
      );
    }
    try {
      return await _remote.load(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        type: type,
      );
    } catch (_) {
      return _local.load(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        type: type,
      );
    }
  }
}
