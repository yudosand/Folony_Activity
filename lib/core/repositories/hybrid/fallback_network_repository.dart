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
    return _guard(
      remote: () => _remote.upsert(profile),
      local: () => _local.upsert(profile),
    );
  }

  @override
  Future<void> delete(String profileId) {
    return _guard(
      remote: () => _remote.delete(profileId),
      local: () => _local.delete(profileId),
    );
  }

  @override
  Future<NetworkProfile> appendFollowUp({
    required String profileId,
    required NetworkFollowUpRecord followUp,
    NetworkProfileStatus? nextStatus,
  }) {
    return _guard(
      remote: () => _remote.appendFollowUp(
        profileId: profileId,
        followUp: followUp,
        nextStatus: nextStatus,
      ),
      local: () => _local.appendFollowUp(
        profileId: profileId,
        followUp: followUp,
        nextStatus: nextStatus,
      ),
    );
  }

  Future<T> _guard<T>({
    required Future<T> Function() remote,
    required Future<T> Function() local,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return local();
    }
    try {
      return await remote();
    } catch (_) {
      return local();
    }
  }
}
