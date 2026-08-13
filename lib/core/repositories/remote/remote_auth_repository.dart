import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
import '../../models/remote_attachment.dart';
import '../../network/simple_api_client.dart';
import '../auth_repository.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({
    required SimpleApiClient client,
  }) : _client = client;

  static const _tokenKey = 'hex.remote.auth.token';
  static const _userKey = 'hex.remote.auth.user';

  final SimpleApiClient _client;

  @override
  Future<AppUser?> currentUser() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    _client.setAuthToken(token);
    final cachedUser = _readCachedUser(preferences);
    try {
      final response = await _client.get('/me');
      final user = AppUser.fromJson(_unwrapMap(response));
      await preferences.setString(_userKey, jsonEncode(user.toJson()));
      return user;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearLocalAuth(preferences);
        return null;
      }
      return cachedUser;
    } catch (_) {
      return cachedUser;
    }
  }

  @override
  Future<AppUser> signIn({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/login',
      body: {
        'identifier': identifier,
        'password': password,
      },
    );

    final payload = _unwrapMap(response);
    final token = payload['token'] as String? ?? '';
    final userJson = payload['user'] is Map<String, dynamic>
        ? payload['user'] as Map<String, dynamic>
        : payload['user'] is Map
            ? Map<String, dynamic>.from(payload['user'] as Map)
            : payload;
    final user = AppUser.fromJson(userJson);
    final preferences = await SharedPreferences.getInstance();

    _client.setAuthToken(token);
    await preferences.setString(_tokenKey, token);
    await preferences.setString(_userKey, jsonEncode(user.toJson()));

    return user;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _client.post(
      '/auth/change-password',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
    );
  }

  @override
  Future<AppUser> updateProfilePhoto(RemoteAttachment profilePhoto) async {
    final response = await _client.post(
      '/profile/photo',
      body: {
        'profile_photo': profilePhoto.toJson(),
      },
    );

    final user = AppUser.fromJson(_unwrapMap(response));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userKey, jsonEncode(user.toJson()));
    return user;
  }

  @override
  Future<AppUser> deleteProfilePhoto() async {
    final response = await _client.delete('/profile/photo');

    final user = AppUser.fromJson(_unwrapMap(response));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_userKey, jsonEncode(user.toJson()));
    return user;
  }

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    await _client.post(
      '/devices/push-token',
      body: {
        'token': token,
        'platform': platform,
        'device_name': deviceName,
        'app_version': appVersion,
      },
    );
  }

  @override
  Future<void> unregisterPushToken({
    required String token,
  }) async {
    await _client.delete(
      '/devices/push-token',
      queryParameters: {
        'token': token,
      },
    );
  }

  @override
  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      await _client.post('/auth/logout');
    } catch (_) {
      // clear local state even if remote logout fails
    }
    await _clearLocalAuth(preferences);
  }

  Future<void> _clearLocalAuth(SharedPreferences preferences) async {
    _client.setAuthToken(null);
    await preferences.remove(_tokenKey);
    await preferences.remove(_userKey);
  }

  AppUser? _readCachedUser(SharedPreferences preferences) {
    final rawUser = preferences.getString(_userKey);
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return AppUser.fromJson(decoded);
      }
      if (decoded is Map) {
        return AppUser.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Ignore malformed cache and fall back to network.
    }

    return null;
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
