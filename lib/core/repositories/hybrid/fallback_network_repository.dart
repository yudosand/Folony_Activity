import '../../models/network_profile.dart';
import '../network_repository.dart';
import 'workflow_repository_mode.dart';

class FallbackNetworkRepository implements NetworkRepository {
  const FallbackNetworkRepository({
    required this.mode,
    required NetworkRepository remote,
    required NetworkRepository local,
  })  : _remote = remote,
        _local = local;

  final WorkflowRepositoryMode mode;
  final NetworkRepository _remote;
  final NetworkRepository _local;

  @override
  Future<List<NetworkProfile>> listOwnedByUser({
    required String userId,
    NetworkProfileType? type,
  }) {
    return _guard(
      remote: () => _remote.listOwnedByUser(userId: userId, type: type),
      local: () => _local.listOwnedByUser(userId: userId, type: type),
    );
  }

  @override
  Future<List<NetworkProfile>> listTeamUkm({
    required String areaManagerId,
  }) {
    return _guard(
      remote: () => _remote.listTeamUkm(areaManagerId: areaManagerId),
      local: () => _local.listTeamUkm(areaManagerId: areaManagerId),
    );
  }

  @override
  Future<NetworkProfile> upsert(NetworkProfile profile) {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.upsert(profile);
    }
    return _remote.upsert(profile);
  }

  @override
  Future<void> delete(String profileId) {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.delete(profileId);
    }
    return _remote.delete(profileId);
  }

  @override
  Future<NetworkProfile> appendFollowUp({
    required String profileId,
    required NetworkFollowUpRecord followUp,
    NetworkProfileStatus? nextStatus,
  }) {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.appendFollowUp(
        profileId: profileId,
        followUp: followUp,
        nextStatus: nextStatus,
      );
    }
    return _remote.appendFollowUp(
      profileId: profileId,
      followUp: followUp,
      nextStatus: nextStatus,
    );
  }

  Future<T> _guard<T>({
    required Future<T> Function() remote,
    required Future<T> Function() local,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return local();
    }
    return remote();
  }
}
