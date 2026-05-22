import 'remote_attachment.dart';

class FaceProfile {
  const FaceProfile({
    required this.id,
    required this.userId,
    required this.status,
    required this.samples,
    required this.samplesCount,
    required this.biometricTemplateReady,
    this.enrolledAt,
    this.lastVerifiedAt,
    this.verificationMode,
    this.note,
  });

  final String id;
  final String userId;
  final String status;
  final List<RemoteAttachment> samples;
  final int samplesCount;
  final bool biometricTemplateReady;
  final DateTime? enrolledAt;
  final DateTime? lastVerifiedAt;
  final String? verificationMode;
  final String? note;

  bool get isEnrolled => status == 'active' && samplesCount >= 3;

  factory FaceProfile.empty({required String userId}) {
    return FaceProfile(
      id: '',
      userId: userId,
      status: 'pending',
      samples: const [],
      samplesCount: 0,
      biometricTemplateReady: false,
    );
  }

  factory FaceProfile.fromJson(Map<String, dynamic> json) {
    final samplesJson = json['samples'];
    final samples = samplesJson is List
        ? samplesJson
            .whereType<Map>()
            .map((item) => RemoteAttachment.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <RemoteAttachment>[];

    return FaceProfile(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      samples: samples,
      samplesCount: (json['samples_count'] as num?)?.toInt() ?? samples.length,
      biometricTemplateReady:
          json['biometric_template_ready'] as bool? ?? false,
      enrolledAt: _parseDateTime(json['enrolled_at']),
      lastVerifiedAt: _parseDateTime(json['last_verified_at']),
      verificationMode: json['verification_mode'] as String?,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'status': status,
      'samples': samples.map((item) => item.toJson()).toList(),
      'samples_count': samplesCount,
      'biometric_template_ready': biometricTemplateReady,
      'enrolled_at': enrolledAt?.toIso8601String(),
      'last_verified_at': lastVerifiedAt?.toIso8601String(),
      'verification_mode': verificationMode,
      'note': note,
    };
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
