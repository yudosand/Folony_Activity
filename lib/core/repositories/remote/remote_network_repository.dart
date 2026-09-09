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
    String? scope,
  }) async {
    return _loadPagedList(
      '/network',
      queryParameters: {
        if (type != null) 'type': type.name,
        if (scope != null) 'scope': scope,
      },
    );
  }

  @override
  Future<NetworkProfilePage> listOwnedByUserPage({
    required String userId,
    NetworkProfileType? type,
    String? scope,
    required int page,
    required int perPage,
  }) async {
    final response = await _getPageWithRetry(
      '/network',
      queryParameters: {
        if (type != null) 'type': type.name,
        if (scope != null) 'scope': scope,
        'per_page': '$perPage',
        'page': '$page',
      },
    );
    final items = _decodeList(response);
    final meta = _unwrapMeta(response);
    final currentPage = _intFromJson(meta['current_page']) ?? page;
    final responsePerPage = _intFromJson(meta['per_page']) ?? perPage;
    final count = _intFromJson(meta['count']) ?? items.length;
    final totalCount = _intFromJson(meta['total']);
    final lastPage = _intFromJson(meta['last_page']);
    final hasMore = _boolFromJson(meta['has_more']);

    return NetworkProfilePage(
      items: items,
      currentPage: currentPage,
      perPage: responsePerPage,
      hasMore: hasMore ??
          (lastPage != null
              ? currentPage < lastPage
              : count >= responsePerPage && items.length >= responsePerPage),
      totalCount: totalCount,
    );
  }

  @override
  Future<List<NetworkProfile>> listTeamUkm({
    required String areaManagerId,
  }) async {
    return _loadPagedList(
      '/network/team-ukm',
    );
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

  Future<List<NetworkProfile>> _loadPagedList(
    String path, {
    Map<String, String> queryParameters = const {},
  }) async {
    const perPage = 50;
    // Monitoring Jaringan HR adalah sumber utama data area. Ambil semua window
    // yang tersedia supaya data area kerja tidak berhenti di page pertama.
    const maxPages = 400;
    final items = <NetworkProfile>[];

    for (var page = 1; page <= maxPages; page++) {
      final dynamic response;
      try {
        response = await _getPageWithRetry(
          path,
          queryParameters: {
            ...queryParameters,
            'per_page': '$perPage',
            'page': '$page',
          },
        );
      } catch (_) {
        if (items.isNotEmpty) {
          break;
        }
        rethrow;
      }
      final pageItems = _decodeList(response);
      final meta = _unwrapMeta(response);
      final lastPage = _intFromJson(meta['last_page']);
      final hasMore = _boolFromJson(meta['has_more']);
      if (pageItems.isEmpty) {
        break;
      }
      items.addAll(pageItems);
      if (hasMore == false) {
        break;
      }
      if (lastPage != null && page >= lastPage) {
        break;
      }
      if (pageItems.length < perPage) {
        break;
      }
    }

    return items;
  }

  Future<dynamic> _getPageWithRetry(
    String path, {
    required Map<String, String> queryParameters,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _client.get(path, queryParameters: queryParameters);
      } catch (error) {
        lastError = error;
        if (attempt == 3) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 450 * attempt));
      }
    }
    throw lastError ?? StateError('Data jaringan belum berhasil dimuat.');
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

  Map<String, dynamic> _unwrapMeta(dynamic response) {
    if (response is Map<String, dynamic> && response['meta'] is Map) {
      return Map<String, dynamic>.from(response['meta'] as Map);
    }
    if (response is Map && response['meta'] is Map) {
      return Map<String, dynamic>.from(response['meta'] as Map);
    }
    return const {};
  }

  int? _intFromJson(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  bool? _boolFromJson(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String && value.trim().isNotEmpty) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
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
