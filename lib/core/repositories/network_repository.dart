import '../models/network_profile.dart';

abstract class NetworkRepository {
  Future<List<NetworkProfile>> listOwnedByUser({
    required String userId,
    NetworkProfileType? type,
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
