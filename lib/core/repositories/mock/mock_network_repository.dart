import '../../models/network_profile.dart';
import '../network_repository.dart';

class MockNetworkRepository implements NetworkRepository {
  final Map<String, List<NetworkProfile>> _profilesByOwner = {};

  @override
  Future<List<NetworkProfile>> listOwnedByUser({
    required String userId,
    NetworkProfileType? type,
  }) async {
    final profiles =
        List<NetworkProfile>.from(_profilesByOwner[userId] ?? const []);
    if (type == null) {
      profiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return profiles;
    }

    final filtered = profiles.where((item) => item.type == type).toList();
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  @override
  Future<List<NetworkProfile>> listTeamUkm({
    required String areaManagerId,
  }) async {
    final profiles = _profilesByOwner.values
        .expand((items) => items)
        .where((item) => item.type == NetworkProfileType.ukm)
        .where((item) => item.ownerRole.name == 'fgg')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return profiles;
  }

  @override
  Future<NetworkProfile> upsert(NetworkProfile profile) async {
    final profiles = _profilesByOwner.putIfAbsent(profile.ownerId, () => []);
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      profiles.insert(0, profile);
    } else {
      profiles[index] = profile;
    }
    return profile;
  }

  @override
  Future<void> delete(String profileId) async {
    for (final profiles in _profilesByOwner.values) {
      profiles.removeWhere((item) => item.id == profileId);
    }
  }

  @override
  Future<NetworkProfile> appendFollowUp({
    required String profileId,
    required NetworkFollowUpRecord followUp,
    NetworkProfileStatus? nextStatus,
  }) async {
    for (final entry in _profilesByOwner.entries) {
      final index = entry.value.indexWhere((item) => item.id == profileId);
      if (index == -1) {
        continue;
      }

      final current = entry.value[index];
      final updated = NetworkProfile(
        id: current.id,
        ownerId: current.ownerId,
        ownerName: current.ownerName,
        ownerRole: current.ownerRole,
        type: current.type,
        name: current.name,
        address: current.address,
        territoryProvince: current.territoryProvince,
        territoryCity: current.territoryCity,
        territoryDistrict: current.territoryDistrict,
        territorySubdistrict: current.territorySubdistrict,
        businessType: current.businessType,
        phoneNumber: current.phoneNumber,
        status: nextStatus ?? current.status,
        createdAt: current.createdAt,
        referenceName: current.referenceName,
        note: current.note,
        photo: current.photo,
        personalityMetrics: current.personalityMetrics,
        documents: current.documents,
        followUps: [followUp, ...current.followUps],
      );
      entry.value[index] = updated;
      return updated;
    }

    throw StateError('Network profile with id $profileId not found');
  }
}
