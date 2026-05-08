import '../models/app_user.dart';

abstract class AuthRepository {
  Future<AppUser> signIn({
    required String identifier,
    required String password,
  });

  Future<void> signOut();

  Future<AppUser?> currentUser();
}
