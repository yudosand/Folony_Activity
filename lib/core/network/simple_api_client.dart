import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    required this.uri,
  });

  final int statusCode;
  final String message;
  final Uri uri;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class SimpleApiClient {
  SimpleApiClient({
    required this.baseUrl,
  });

  final String baseUrl;
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return _send(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
    );
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
    );
  }

  Future<dynamic> delete(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return _send(
      method: 'DELETE',
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> postMultipart(
    String path, {
    required String fileField,
    required String filePath,
    Map<String, String>? fields,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final boundary =
          '----hex-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
      final uri = _resolveUri(path);
      final request = await client.openUrl('POST', uri);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_authToken');
      }

      final payload = BytesBuilder();
      for (final entry in (fields ?? const <String, String>{}).entries) {
        payload.add(utf8.encode('--$boundary\r\n'));
        payload.add(
          utf8.encode(
            'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n',
          ),
        );
        payload.add(utf8.encode('${entry.value}\r\n'));
      }

      final fileName = file.uri.pathSegments.isEmpty
          ? 'upload.bin'
          : file.uri.pathSegments.last;
      payload.add(utf8.encode('--$boundary\r\n'));
      payload.add(
        utf8.encode(
          'Content-Disposition: form-data; name="$fileField"; filename="$fileName"\r\n',
        ),
      );
      payload.add(
        utf8.encode(
          'Content-Type: ${_mimeTypeFor(fileName)}\r\n\r\n',
        ),
      );
      payload.add(bytes);
      payload.add(utf8.encode('\r\n--$boundary--\r\n'));

      request.add(payload.takeBytes());
      final response = await request.close().timeout(
            const Duration(seconds: 20),
          );
      return _decodeResponse(response, 'POST', uri);
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> _send({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = _resolveUri(path, queryParameters: queryParameters);
      final request = await client.openUrl(method, uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_authToken');
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(
            const Duration(seconds: 12),
          );
      return _decodeResponse(response, method, uri);
    } finally {
      client.close(force: true);
    }
  }

  Uri _resolveUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final baseUri = Uri.parse(baseUrl);
    final effectiveBaseUri = baseUri.path.endsWith('/')
        ? baseUri
        : baseUri.replace(path: '${baseUri.path}/');
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return effectiveBaseUri
        .resolve(normalizedPath)
        .replace(queryParameters: queryParameters);
  }

  Future<dynamic> _decodeResponse(
    HttpClientResponse response,
    String method,
    Uri uri,
  ) async {
    final payload = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(payload, response.statusCode, method, uri),
        uri: uri,
      );
    }

    if (payload.trim().isEmpty) {
      return null;
    }

    return jsonDecode(payload);
  }

  String _mimeTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  String _extractErrorMessage(
    String payload,
    int statusCode,
    String method,
    Uri uri,
  ) {
    if (payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message'];
          if (message is String && message.isNotEmpty) {
            return message;
          }
          final errors = decoded['errors'];
          if (errors is Map) {
            for (final value in errors.values) {
              if (value is List && value.isNotEmpty) {
                final first = value.first;
                if (first is String && first.isNotEmpty) {
                  return first;
                }
              }
            }
          }
        }
      } catch (_) {
        // Ignore parse failures and fall back to generic error below.
      }
    }
    return 'HTTP $statusCode for $method $uri';
  }
}
