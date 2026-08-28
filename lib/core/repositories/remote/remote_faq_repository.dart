import '../../models/faq_item.dart';
import '../../network/simple_api_client.dart';
import '../faq_repository.dart';

class RemoteFaqRepository implements FaqRepository {
  const RemoteFaqRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<List<FaqItem>> listActive() async {
    final response = await _client.get('/faqs');
    final items = _unwrapList(response);
    return items
        .whereType<Map>()
        .map((item) => FaqItem.fromJson(Map<String, dynamic>.from(item)))
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
