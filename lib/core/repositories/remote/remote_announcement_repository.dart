import '../../models/announcement.dart';
import '../../network/simple_api_client.dart';
import '../announcement_repository.dart';

class RemoteAnnouncementRepository implements AnnouncementRepository {
  const RemoteAnnouncementRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<List<Announcement>> listActive() async {
    final response = await _client.get('/announcements');
    final items = _unwrapList(response);
    return items
        .whereType<Map>()
        .map((item) => Announcement.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  List<dynamic> _unwrapList(dynamic response) {
    if (response is Map<String, dynamic> && response['data'] is List) {
      return response['data'] as List;
    }
    if (response is Map && response['data'] is List) {
      return response['data'] as List;
    }
    if (response is List) {
      return response;
    }
    return const [];
  }
}
