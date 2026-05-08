import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
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

    final cachedUser = preferences.getString(_userKey);
    if (cachedUser != null && cachedUser.isNotEmpty) {
      try {
        final json = jsonDecode(cachedUser);
        if (json is Map<String, dynamic>) {
          return AppUser.fromJson(json);
        }
        if (json is Map) {
          return AppUser.fromJson(Map<String, dynamic>.from(json));
        }
      } catch (_) {
        // fall back to network fetch below
      }
    }

    final response = await _client.get('/me');
    final user = AppUser.fromJson(_unwrapMap(response));
    await preferences.setString(_userKey, jsonEncode(user.toJson()));
    return user;
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
  Future<void> signOut() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      await _client.post('/auth/logout');
    } catch (_) {
      // clear local state even if remote logout fails
    }
    _client.setAuthToken(null);
    await preferences.remove(_tokenKey);
    await preferences.remove(_userKey);
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
