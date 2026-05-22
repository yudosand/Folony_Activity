import '../../models/face_profile.dart';
import '../../models/face_verification_result.dart';
import '../../models/remote_attachment.dart';
import '../../../features/face/domain/face_signature_math.dart';
import '../face_profile_repository.dart';

class MockFaceProfileRepository implements FaceProfileRepository {
  MockFaceProfileRepository({
    String userId = 'mock-user',
  }) : _profile = FaceProfile(
          id: 'mock-face-profile',
          userId: userId,
          status: 'active',
          samples: List.generate(
            3,
            (index) => RemoteAttachment(
              id: 'mock-face-sample-$index',
              fileName: 'mock-face-sample-$index.jpg',
              mimeType: 'image/jpeg',
              url: 'https://mock.local/face-sample-$index.jpg',
            ),
          ),
          samplesCount: 3,
          biometricTemplateReady: true,
          enrolledAt: DateTime.now().subtract(const Duration(days: 7)),
          verificationMode: 'mock',
          note: 'Profil wajah mock aktif.',
        );

  FaceProfile _profile;
  List<double> _template = const [0.14, 0.32, 0.28, 0.11, 0.19];

  @override
  Future<FaceProfile> currentProfile() async => _profile;

  @override
  Future<FaceProfile> enroll({
    required List<RemoteAttachment> samples,
    required List<double> biometricTemplate,
    String? note,
  }) async {
    _template = biometricTemplate;
    _profile = FaceProfile(
      id: _profile.id,
      userId: _profile.userId,
      status: samples.length >= 3 ? 'active' : 'pending',
      samples: samples,
      samplesCount: samples.length,
      biometricTemplateReady: biometricTemplate.length >= 64,
      enrolledAt: DateTime.now(),
      verificationMode: 'mock',
      note: note ?? 'Enrollment wajah mock selesai.',
    );
    return _profile;
  }

  @override
  Future<FaceVerificationResult> verify({
    required String action,
    required RemoteAttachment capture,
    required List<double> signature,
    required double livenessScore,
    String? note,
  }) async {
    final matchScore = FaceSignatureMath.cosineSimilarityScore(
      _template,
      signature,
    );
    final decision = !_profile.isEnrolled
        ? 'rejected'
        : matchScore >= 82 && livenessScore >= 72
            ? 'verified'
            : matchScore >= 74 && livenessScore >= 55
                ? 'retry'
                : 'rejected';
    final verified = decision == 'verified';
    return FaceVerificationResult(
      verified: verified,
      decision: decision,
      matchScore: matchScore,
      livenessScore: livenessScore,
      capture: capture,
      profile: _profile,
      note: note ??
          (verified
              ? 'Verifikasi wajah mock berhasil.'
              : decision == 'retry'
                  ? 'Verifikasi wajah mock masih borderline. Coba scan ulang.'
                  : 'Signature wajah tidak cukup mirip atau liveness terlalu rendah.'),
      verifiedAt: DateTime.now(),
    );
  }
}
