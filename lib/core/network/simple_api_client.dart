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
  final Map<String, String> _dnsFallbackHosts = {
    'absent.folony.co.id': '137.59.126.155',
    'staging-absent.folony.co.id': '137.59.126.155',
  };

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
    final client = _createHttpClient();
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final boundary =
          '----hex-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
      final uri = _resolveUri(path);
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

      final payloadBytes = payload.takeBytes();
      final response = await _openWithDnsFallback(
        client: client,
        method: 'POST',
        uri: uri,
        configureRequest: (request, originalHost) {
          request.headers.set(
            HttpHeaders.contentTypeHeader,
            'multipart/form-data; boundary=$boundary',
          );
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          request.headers.set(HttpHeaders.connectionHeader, 'close');
          if (originalHost != null) {
            request.headers.set(HttpHeaders.hostHeader, originalHost);
          }
          if (_authToken != null && _authToken!.isNotEmpty) {
            request.headers
                .set(HttpHeaders.authorizationHeader, 'Bearer $_authToken');
          }
          request.contentLength = payloadBytes.length;
          request.add(payloadBytes);
        },
        timeout: const Duration(seconds: 20),
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
    final client = _createHttpClient();
    try {
      final uri = _resolveUri(path, queryParameters: queryParameters);
      final encodedBody = body == null ? null : jsonEncode(body);
      final response = await _openWithDnsFallback(
        client: client,
        method: method,
        uri: uri,
        configureRequest: (request, originalHost) {
          request.headers.contentType = ContentType.json;
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          if (originalHost != null) {
            request.headers.set(HttpHeaders.hostHeader, originalHost);
          }
          if (_authToken != null && _authToken!.isNotEmpty) {
            request.headers
                .set(HttpHeaders.authorizationHeader, 'Bearer $_authToken');
          }

          if (encodedBody != null) {
            request.write(encodedBody);
          }
        },
        timeout: const Duration(seconds: 12),
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

  HttpClient _createHttpClient() {
    return HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..badCertificateCallback = _allowKnownFallbackCertificate;
  }

  Future<HttpClientResponse> _openWithDnsFallback({
    required HttpClient client,
    required String method,
    required Uri uri,
    required void Function(HttpClientRequest request, String? originalHost)
        configureRequest,
    required Duration timeout,
  }) async {
    try {
      final request = await client.openUrl(method, uri);
      configureRequest(request, null);
      return request.close().timeout(timeout);
    } on SocketException catch (error) {
      final fallbackUri = _fallbackUriForDnsError(uri, error);
      if (fallbackUri == null) {
        rethrow;
      }

      final request = await client.openUrl(method, fallbackUri);
      configureRequest(request, uri.host);
      return request.close().timeout(timeout);
    }
  }

  Uri? _fallbackUriForDnsError(Uri uri, SocketException error) {
    final message = error.message.toLowerCase();
    if (!message.contains('failed host lookup') ||
        uri.scheme != 'https' ||
        !_dnsFallbackHosts.containsKey(uri.host)) {
      return null;
    }

    return uri.replace(host: _dnsFallbackHosts[uri.host]);
  }

  bool _allowKnownFallbackCertificate(
    X509Certificate certificate,
    String host,
    int port,
  ) {
    String? expectedHost;
    for (final entry in _dnsFallbackHosts.entries) {
      if (entry.value == host) {
        expectedHost = entry.key;
        break;
      }
    }

    if (expectedHost == null) {
      return false;
    }

    return certificate.subject.contains(expectedHost);
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
        message:
            _extractErrorMessage(payload, response.statusCode, method, uri),
        uri: uri,
      );
    }

    if (payload.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(payload);
    } catch (_) {
      final sanitizedPayload = _extractJsonPayload(payload);
      if (sanitizedPayload != null) {
        return jsonDecode(sanitizedPayload);
      }
      throw ApiException(
        statusCode: response.statusCode,
        message:
            'Server mengirim respons tidak valid. Coba ulangi, atau cek backend staging lokal.',
        uri: uri,
      );
    }
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
        final decoded = jsonDecode(_extractJsonPayload(payload) ?? payload);
        if (decoded is Map<String, dynamic>) {
          final errors = decoded['errors'];
          if (errors is Map) {
            final errorMessages = <String>[];
            for (final value in errors.values) {
              if (value is List && value.isNotEmpty) {
                final first = value.first;
                if (first is String && first.isNotEmpty) {
                  errorMessages.add(first);
                }
              } else if (value is String && value.isNotEmpty) {
                errorMessages.add(value);
              }
            }
            if (errorMessages.isNotEmpty) {
              return errorMessages.join(' ');
            }
          }
          final message = decoded['message'];
          if (message is String && message.isNotEmpty) {
            return message;
          }
          final data = decoded['data'];
          if (data is Map<String, dynamic>) {
            final dataMessage = data['message'];
            if (dataMessage is String && dataMessage.isNotEmpty) {
              return dataMessage;
            }
            final note = data['note'];
            if (note is String && note.isNotEmpty) {
              return note;
            }
          } else if (data is Map) {
            final normalized = Map<String, dynamic>.from(data);
            final dataMessage = normalized['message'];
            if (dataMessage is String && dataMessage.isNotEmpty) {
              return dataMessage;
            }
            final note = normalized['note'];
            if (note is String && note.isNotEmpty) {
              return note;
            }
          }
        }
      } catch (_) {
        final trimmedPayload = payload.trim();
        if (trimmedPayload.isNotEmpty) {
          return trimmedPayload.length > 240
              ? '${trimmedPayload.substring(0, 240)}...'
              : trimmedPayload;
        }
      }
    }
    return 'HTTP $statusCode for $method $uri';
  }

  String? _extractJsonPayload(String payload) {
    final trimmedPayload = payload.trim();
    if (trimmedPayload.startsWith('{') || trimmedPayload.startsWith('[')) {
      return trimmedPayload;
    }

    final objectStart = trimmedPayload.indexOf('{');
    final arrayStart = trimmedPayload.indexOf('[');
    final candidates = [
      if (objectStart >= 0) objectStart,
      if (arrayStart >= 0) arrayStart,
    ]..sort();

    for (final start in candidates) {
      final candidate = trimmedPayload.substring(start);
      try {
        jsonDecode(candidate);
        return candidate;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
