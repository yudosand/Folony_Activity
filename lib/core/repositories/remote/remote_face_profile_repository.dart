import '../../models/face_profile.dart';
import '../../models/face_verification_result.dart';
import '../../models/remote_attachment.dart';
import '../../network/simple_api_client.dart';
import '../face_profile_repository.dart';

class RemoteFaceProfileRepository implements FaceProfileRepository {
  const RemoteFaceProfileRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<FaceProfile> currentProfile() async {
    final response = await _client.get('/face/profile');
    return FaceProfile.fromJson(_unwrapMap(response));
  }

  @override
  Future<FaceProfile> enroll({
    required List<RemoteAttachment> samples,
    required List<double> biometricTemplate,
    String? note,
  }) async {
    final response = await _client.post(
      '/face/profile',
      body: {
        'samples': samples.map((item) => item.toJson()).toList(),
        'biometric_template': biometricTemplate,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return FaceProfile.fromJson(_unwrapMap(response));
  }

  @override
  Future<FaceVerificationResult> verify({
    required String action,
    required RemoteAttachment capture,
    required List<double> signature,
    required double livenessScore,
    String? note,
  }) async {
    final response = await _client.post(
      '/face/verify',
      body: {
        'action': action,
        'capture': capture.toJson(),
        'signature': signature,
        'liveness_score': livenessScore,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return FaceVerificationResult.fromJson(_unwrapMap(response));
  }

  Map<String, dynamic> _unwrapMap(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return response;
    }
    if (response is Map) {
      if (response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return Map<String, dynamic>.from(response);
    }
    return const {};
  }
}
