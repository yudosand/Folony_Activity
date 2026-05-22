import '../enums/app_role.dart';
import 'remote_attachment.dart';

enum NetworkProfileType {
  ukm,
  mitra;
}

enum NetworkProfileStatus {
  draft,
  followUp,
  completed,
  archived;
}

class PersonalityMetric {
  const PersonalityMetric({
    required this.label,
    required this.score,
  });

  final String label;
  final double score;

  factory PersonalityMetric.fromJson(Map<String, dynamic> json) {
    return PersonalityMetric(
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'score': score,
    };
  }
}

class NetworkDocumentRecord {
  const NetworkDocumentRecord({
    required this.label,
    required this.exists,
    required this.isValid,
    this.attachment,
  });

  final String label;
  final bool exists;
  final bool isValid;
  final RemoteAttachment? attachment;

  factory NetworkDocumentRecord.fromJson(Map<String, dynamic> json) {
    return NetworkDocumentRecord(
      label: json['label'] as String? ?? '',
      exists: json['exists'] as bool? ?? false,
      isValid: json['is_valid'] as bool? ?? false,
      attachment: json['attachment'] is Map<String, dynamic>
          ? RemoteAttachment.fromJson(
              json['attachment'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'exists': exists,
      'is_valid': isValid,
      'attachment': attachment?.toJson(),
    };
  }
}

class NetworkFollowUpRecord {
  const NetworkFollowUpRecord({
    required this.id,
    required this.title,
    required this.note,
    required this.actorId,
    required this.actorName,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String note;
  final String actorId;
  final String actorName;
  final DateTime createdAt;

  factory NetworkFollowUpRecord.fromJson(Map<String, dynamic> json) {
    return NetworkFollowUpRecord(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      actorId: json['actor_id'] as String? ?? '',
      actorName: json['actor_name'] as String? ?? '',
      createdAt: _dateTimeFromJson(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'actor_id': actorId,
      'actor_name': actorName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class NetworkProfile {
  const NetworkProfile({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerRole,
    required this.type,
    required this.name,
    required this.address,
    required this.territoryProvince,
    required this.territoryCity,
    required this.territoryDistrict,
    required this.territorySubdistrict,
    required this.businessType,
    required this.phoneNumber,
    required this.status,
    required this.createdAt,
    this.referenceName,
    this.note,
    this.photo,
    this.personalityMetrics = const [],
    this.documents = const [],
    this.followUps = const [],
    this.latitude,
    this.longitude,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final AppRole ownerRole;
  final NetworkProfileType type;
  final String name;
  final String address;
  final String territoryProvince;
  final String territoryCity;
  final String territoryDistrict;
  final String territorySubdistrict;
  final String businessType;
  final String phoneNumber;
  final NetworkProfileStatus status;
  final DateTime createdAt;
  final String? referenceName;
  final String? note;
  final RemoteAttachment? photo;
  final List<PersonalityMetric> personalityMetrics;
  final List<NetworkDocumentRecord> documents;
  final List<NetworkFollowUpRecord> followUps;
  final double? latitude;
  final double? longitude;

  factory NetworkProfile.fromJson(Map<String, dynamic> json) {
    return NetworkProfile(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? '',
      ownerRole: AppRole.values.firstWhere(
        (role) => role.name == json['owner_role'],
        orElse: () => AppRole.fgg,
      ),
      type: NetworkProfileType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => NetworkProfileType.ukm,
      ),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      territoryProvince: json['territory_province'] as String? ?? '',
      territoryCity: json['territory_city'] as String? ?? '',
      territoryDistrict: json['territory_district'] as String? ?? '',
      territorySubdistrict: json['territory_subdistrict'] as String? ?? '',
      businessType: json['business_type'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      status: NetworkProfileStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => NetworkProfileStatus.draft,
      ),
      createdAt: _dateTimeFromJson(json['created_at']),
      referenceName: json['reference_name'] as String?,
      note: json['note'] as String?,
      photo: json['photo'] is Map<String, dynamic>
          ? RemoteAttachment.fromJson(json['photo'] as Map<String, dynamic>)
          : null,
      personalityMetrics: _metricsFromJson(json['personality_metrics']),
      documents: _documentsFromJson(json['documents']),
      followUps: _followUpsFromJson(json['follow_ups']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_role': ownerRole.name,
      'type': type.name,
      'name': name,
      'address': address,
      'territory_province': territoryProvince,
      'territory_city': territoryCity,
      'territory_district': territoryDistrict,
      'territory_subdistrict': territorySubdistrict,
      'business_type': businessType,
      'phone_number': phoneNumber,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'reference_name': referenceName,
      'note': note,
      'photo': photo?.toJson(),
      'personality_metrics':
          personalityMetrics.map((item) => item.toJson()).toList(),
      'documents': documents.map((item) => item.toJson()).toList(),
      'follow_ups': followUps.map((item) => item.toJson()).toList(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

DateTime _dateTimeFromJson(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

List<PersonalityMetric> _metricsFromJson(Object? value) {
  if (value is List) {
    return value
        .whereType<Map<String, dynamic>>()
        .map(PersonalityMetric.fromJson)
        .toList();
  }
  return const [];
}

List<NetworkDocumentRecord> _documentsFromJson(Object? value) {
  if (value is List) {
    return value
        .whereType<Map<String, dynamic>>()
        .map(NetworkDocumentRecord.fromJson)
        .toList();
  }
  return const [];
}

List<NetworkFollowUpRecord> _followUpsFromJson(Object? value) {
  if (value is List) {
    return value
        .whereType<Map<String, dynamic>>()
        .map(NetworkFollowUpRecord.fromJson)
        .toList();
  }
  return const [];
}
