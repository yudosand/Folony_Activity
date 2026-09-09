import '../models/network_profile.dart';

class NetworkProfilePage {
  const NetworkProfilePage({
    required this.items,
    required this.currentPage,
    required this.perPage,
    required this.hasMore,
    this.totalCount,
  });

  final List<NetworkProfile> items;
  final int currentPage;
  final int perPage;
  final bool hasMore;
  final int? totalCount;
}

abstract class NetworkRepository {
  Future<List<NetworkProfile>> listOwnedByUser({
    required String userId,
    NetworkProfileType? type,
    String? scope,
  });

  Future<NetworkProfilePage> listOwnedByUserPage({
    required String userId,
    NetworkProfileType? type,
    String? scope,
    required int page,
    required int perPage,
  });

  Future<List<NetworkProfile>> listTeamUkm({
    required String areaManagerId,
  });

  Future<NetworkProfile> upsert(NetworkProfile profile);

  Future<void> delete(String profileId);

  Future<NetworkProfile> appendFollowUp({
    required String profileId,
    required NetworkFollowUpRecord followUp,
    NetworkProfileStatus? nextStatus,
  });
}
