import 'remote_attachment.dart';
import 'face_profile.dart';

class FaceVerificationResult {
  const FaceVerificationResult({
    required this.verified,
    required this.decision,
    required this.matchScore,
    required this.livenessScore,
    required this.capture,
    required this.profile,
    this.note,
    this.verifiedAt,
  });

  final bool verified;
  final String decision;
  final double? matchScore;
  final double? livenessScore;
  final RemoteAttachment capture;
  final FaceProfile profile;
  final String? note;
  final DateTime? verifiedAt;
  bool get shouldRetry => decision == 'retry';

  factory FaceVerificationResult.fromJson(Map<String, dynamic> json) {
    return FaceVerificationResult(
      verified: json['verified'] as bool? ?? false,
      decision: json['decision'] as String? ?? 'rejected',
      matchScore: (json['match_score'] as num?)?.toDouble(),
      livenessScore: (json['liveness_score'] as num?)?.toDouble(),
      capture: RemoteAttachment.fromJson(
        json['verification_log'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(
                ((json['verification_log']
                            as Map<String, dynamic>)['capture_attachment']
                        as Map?) ??
                    const {},
              )
            : json['verification_log'] is Map
                ? Map<String, dynamic>.from(
                    (((json['verification_log'] as Map)['capture_attachment'])
                            as Map?) ??
                        const {},
                  )
                : const {},
      ),
      profile: FaceProfile.fromJson(
        json['profile'] is Map<String, dynamic>
            ? json['profile'] as Map<String, dynamic>
            : json['profile'] is Map
                ? Map<String, dynamic>.from(json['profile'] as Map)
                : const {},
      ),
      note: json['note'] as String?,
      verifiedAt: _parseFaceVerificationDateTime(
        json['verification_log'] is Map<String, dynamic>
            ? (json['verification_log'] as Map<String, dynamic>)['verified_at']
            : json['verification_log'] is Map
                ? (json['verification_log'] as Map)['verified_at']
                : null,
      ),
    );
  }
}

DateTime? _parseFaceVerificationDateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
