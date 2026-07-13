import 'remote_attachment.dart';

enum AttendanceAction {
  checkIn,
  checkOut,
  outsideOfficeStart,
  outsideOfficeFinish;
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
    this.distanceMeters,
    this.workAreaId,
    this.workAreaName,
    this.workAreaLatitude,
    this.workAreaLongitude,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final String? addressLabel;
  final double? radiusMeters;
  final bool? withinRadius;
  final double? distanceMeters;
  final String? workAreaId;
  final String? workAreaName;
  final double? workAreaLatitude;
  final double? workAreaLongitude;

  factory AttendanceLocationRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceLocationRecord(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      recordedAt: _requiredDateTime(json['recorded_at']),
      addressLabel: json['address_label'] as String?,
      radiusMeters: (json['radius_meters'] as num?)?.toDouble(),
      withinRadius: json['within_radius'] as bool?,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      workAreaId: json['work_area_id'] as String?,
      workAreaName: json['work_area_name'] as String?,
      workAreaLatitude: (json['work_area_latitude'] as num?)?.toDouble(),
      workAreaLongitude: (json['work_area_longitude'] as num?)?.toDouble(),
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
      'distance_meters': distanceMeters,
      'work_area_id': workAreaId,
      'work_area_name': workAreaName,
      'work_area_latitude': workAreaLatitude,
      'work_area_longitude': workAreaLongitude,
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
    this.metadata,
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
  final AttendanceMetadata? metadata;
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
      metadata: json['metadata'] is Map<String, dynamic>
          ? AttendanceMetadata.fromJson(
              json['metadata'] as Map<String, dynamic>,
            )
          : null,
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
      'metadata': metadata?.toJson(),
      'verification': verification?.toJson(),
      'note': note,
    };
  }
}

class AttendanceMetadata {
  const AttendanceMetadata({
    this.attendanceMode,
    this.placeDescription,
    this.ukmName,
    this.reportType,
    this.reportText,
    this.evidenceAttachment,
    this.startedAt,
    this.finishedAt,
    this.startRecordId,
    this.durationMinutes,
  });

  final String? attendanceMode;
  final String? placeDescription;
  final String? ukmName;
  final String? reportType;
  final String? reportText;
  final RemoteAttachment? evidenceAttachment;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? startRecordId;
  final int? durationMinutes;

  factory AttendanceMetadata.fromJson(Map<String, dynamic> json) {
    return AttendanceMetadata(
      attendanceMode: json['attendance_mode'] as String?,
      placeDescription: json['place_description'] as String?,
      ukmName: json['ukm_name'] as String?,
      reportType: json['report_type'] as String?,
      reportText: json['report_text'] as String?,
      evidenceAttachment: json['evidence_attachment'] is Map<String, dynamic>
          ? RemoteAttachment.fromJson(
              json['evidence_attachment'] as Map<String, dynamic>,
            )
          : null,
      startedAt: _optionalDateTime(json['started_at']),
      finishedAt: _optionalDateTime(json['finished_at']),
      startRecordId: json['start_record_id'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attendance_mode': attendanceMode,
      'place_description': placeDescription,
      'ukm_name': ukmName,
      'report_type': reportType,
      'report_text': reportText,
      'evidence_attachment': evidenceAttachment?.toJson(),
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'start_record_id': startRecordId,
      'duration_minutes': durationMinutes,
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

DateTime? _optionalDateTime(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
