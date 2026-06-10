import '../models/app_user.dart';

abstract class AuthRepository {
  Future<AppUser> signIn({
    required String identifier,
    required String password,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  });

  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  });

  Future<void> unregisterPushToken({
    required String token,
  });

  Future<void> signOut();

  Future<AppUser?> currentUser();
}
