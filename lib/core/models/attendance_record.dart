import 'remote_attachment.dart';

enum AttendanceAction {
  checkIn,
  checkOut;
}

enum AttendanceRecordStatus {
  pending,
  success,
  failed;
}

class AttendanceLocationRecord {
  const AttendanceLocationRecord({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.addressLabel,
    this.radiusMeters,
    this.withinRadius,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final String? addressLabel;
  final double? radiusMeters;
  final bool? withinRadius;

  factory AttendanceLocationRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceLocationRecord(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      recordedAt: _requiredDateTime(json['recorded_at']),
      addressLabel: json['address_label'] as String?,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble(),
      withinRadius: json['within_radius'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'recorded_at': recordedAt.toIso8601String(),
      'address_label': addressLabel,
      'radius_meters': radiusMeters,
      'within_radius': withinRadius,
    };
  }
}

class FaceVerificationRecord {
  const FaceVerificationRecord({
    required this.verifiedAt,
    this.decision,
    this.matchScore,
    this.livenessScore,
    this.capture,
    this.note,
  });

  final DateTime verifiedAt;
  final String? decision;
  final double? matchScore;
  final double? livenessScore;
  final RemoteAttachment? capture;
  final String? note;

  factory FaceVerificationRecord.fromJson(Map<String, dynamic> json) {
    return FaceVerificationRecord(
      verifiedAt: _requiredDateTime(json['verified_at']),
      decision: json['decision'] as String?,
      matchScore: (json['match_score'] as num?)?.toDouble(),
      livenessScore: (json['liveness_score'] as num?)?.toDouble(),
      capture: json['capture'] is Map<String, dynamic>
          ? RemoteAttachment.fromJson(json['capture'] as Map<String, dynamic>)
          : null,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verified_at': verifiedAt.toIso8601String(),
      'decision': decision,
      'match_score': matchScore,
      'liveness_score': livenessScore,
      'capture': capture?.toJson(),
      'note': note,
    };
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.workDate,
    required this.action,
    required this.status,
    required this.recordedAt,
    required this.location,
    this.verification,
    this.note,
  });

  final String id;
  final String userId;
  final DateTime workDate;
  final AttendanceAction action;
  final AttendanceRecordStatus status;
  final DateTime recordedAt;
  final AttendanceLocationRecord location;
  final FaceVerificationRecord? verification;
  final String? note;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      workDate: _requiredDateTime(json['work_date']),
      action: AttendanceAction.values.firstWhere(
        (item) => item.name == json['action'],
        orElse: () => AttendanceAction.checkIn,
      ),
      status: AttendanceRecordStatus.values.firstWhere(
        (item) => item.name == json['status'],
        orElse: () => AttendanceRecordStatus.pending,
      ),
      recordedAt: _requiredDateTime(json['recorded_at']),
      location: AttendanceLocationRecord.fromJson(
        json['location'] as Map<String, dynamic>? ?? const {},
      ),
      verification: json['verification'] is Map<String, dynamic>
          ? FaceVerificationRecord.fromJson(
              json['verification'] as Map<String, dynamic>,
            )
          : null,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'work_date': workDate.toIso8601String(),
      'action': action.name,
      'status': status.name,
      'recorded_at': recordedAt.toIso8601String(),
      'location': location.toJson(),
      'verification': verification?.toJson(),
      'note': note,
    };
  }
}

DateTime _requiredDateTime(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
