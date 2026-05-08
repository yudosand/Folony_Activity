import '../../models/heat_map_snapshot.dart';
import '../../network/simple_api_client.dart';
import '../heat_map_repository.dart';

class RemoteHeatMapRepository implements HeatMapRepository {
  const RemoteHeatMapRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<HeatMapSnapshot> load({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? type,
  }) async {
    final response = await _client.get(
      '/heat-map',
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'radius_meters': '$radiusMeters',
        if (type != null) 'type': type,
      },
    );
    return HeatMapSnapshot.fromJson(_unwrapMap(response));
  }

  Map<String, dynamic> _unwrapMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return response;
    }
    if (response is Map) {
      if (response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return Map<String, dynamic>.from(response);
    }
    return const {};
  }
}
