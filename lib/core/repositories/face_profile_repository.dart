import '../models/face_profile.dart';
import '../models/face_verification_result.dart';
import '../models/remote_attachment.dart';

abstract class FaceProfileRepository {
  Future<FaceProfile> currentProfile();

  Future<FaceProfile> enroll({
    required List<RemoteAttachment> samples,
    required List<double> biometricTemplate,
    String? note,
  });

  Future<FaceVerificationResult> verify({
    required String action,
    required RemoteAttachment capture,
    required List<double> signature,
    required double livenessScore,
    String? note,
  });
}
