import '../../../core/models/face_profile.dart';
import '../../../core/network/simple_api_client.dart';

String? faceEnrollmentBlockReason(
  FaceProfile profile, {
  required String actionLabel,
}) {
  if (!profile.isEnrolled) {
    return 'Daftarkan wajah dulu dari menu Akun sebelum $actionLabel.';
  }

  if (!profile.biometricTemplateReady) {
    return 'Template wajah Anda belum siap untuk verifikasi terbaru. Buka menu Akun lalu perbarui enrollment wajah dulu.';
  }

  return null;
}

String describeAttendanceActionError(
  Object error, {
  required String actionLabel,
}) {
  final fallback = 'Proses $actionLabel belum berhasil. Coba lagi sebentar.';

  if (error is ApiException) {
    if (error.statusCode >= 500) {
      return 'Server sedang bermasalah saat memproses $actionLabel. ${error.message}';
    }
    return 'Proses $actionLabel gagal: ${error.message}';
  }

  if (error is StateError) {
    final message = error.message.toString().trim();
    if (message.isNotEmpty) {
      return message;
    }
    return fallback;
  }

  final rawMessage = error.toString().trim();
  if (rawMessage.isEmpty) {
    return fallback;
  }

  return 'Proses $actionLabel gagal: $rawMessage';
}
