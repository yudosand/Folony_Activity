import '../../models/network_profile.dart';
import '../../network/simple_api_client.dart';
import '../network_repository.dart';

class RemoteNetworkRepository implements NetworkRepository {
  const RemoteNetworkRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<List<NetworkProfile>> listOwnedByUser({
    required String userId,
    NetworkProfileType? type,
  }) async {
    final response = await _client.get(
      '/network',
      queryParameters: {
        if (type != null) 'type': type.name,
      },
    );
    return _decodeList(response);
  }

  @override
  Future<List<NetworkProfile>> listTeamUkm({
    required String areaManagerId,
  }) async {
    final response = await _client.get('/network/team-ukm');
    return _decodeList(response);
  }

  @override
  Future<NetworkProfile> upsert(NetworkProfile profile) async {
    final response = await _client.post(
      '/network',
      body: profile.toJson(),
    );
    return _decodeOne(response);
  }

  @override
  Future<void> delete(String profileId) async {
    await _client.delete('/network/$profileId');
  }

  @override
  Future<NetworkProfile> appendFollowUp({
    required String profileId,
    required NetworkFollowUpRecord followUp,
    NetworkProfileStatus? nextStatus,
  }) async {
    final response = await _client.post(
      '/network/$profileId/follow-ups',
      body: {
        ...followUp.toJson(),
        'next_status': nextStatus?.name,
      },
    );
    return _decodeOne(response);
  }

  List<NetworkProfile> _decodeList(dynamic response) {
    final rawList = _unwrapList(response);
    return rawList.map(NetworkProfile.fromJson).toList();
  }

  NetworkProfile _decodeOne(dynamic response) {
    return NetworkProfile.fromJson(_unwrapMap(response));
  }

  List<Map<String, dynamic>> _unwrapList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
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
