import 'package:flutter_test/flutter_test.dart';

import 'package:folony_activity/core/models/face_profile.dart';
import 'package:folony_activity/core/network/simple_api_client.dart';
import 'package:folony_activity/features/attendance/presentation/attendance_feedback.dart';

void main() {
  test('face enrollment block reason requires biometric template readiness',
      () {
    final profile = FaceProfile(
      id: 'face-profile-legacy',
      userId: 'usr_001',
      status: 'active',
      samples: const [],
      samplesCount: 3,
      biometricTemplateReady: false,
    );

    expect(
      faceEnrollmentBlockReason(profile, actionLabel: 'check-in'),
      contains('perbarui enrollment wajah'),
    );
  });

  test('attendance action error hides technical api message for server failure',
      () {
    final error = ApiException(
      statusCode: 500,
      message: 'Internal Server Error',
      uri: Uri.parse('http://localhost/api/face/verify'),
    );

    expect(
      describeAttendanceActionError(error, actionLabel: 'check-in'),
      'Server sedang bermasalah saat memproses check-in. Coba lagi beberapa saat lagi.',
    );
  });

  test('attendance action error keeps state error message readable', () {
    expect(
      describeAttendanceActionError(
        StateError('Capture wajah tidak berhasil diunggah.'),
        actionLabel: 'check-in',
      ),
      'Capture wajah tidak berhasil diunggah.',
    );
  });
}
