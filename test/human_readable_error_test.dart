import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/core/network/human_readable_error.dart';
import 'package:folony_activity/core/network/simple_api_client.dart';

void main() {
  const forbiddenFragments = [
    'ApiException',
    'SocketException',
    'HandshakeException',
    'FormatException',
    'HttpException',
    'TimeoutException',
    'FileSystemException',
    'Bad state',
    'CERTIFICATE_VERIFY_FAILED',
    'Failed host lookup',
    'HTTP 500',
    'https://',
    '<br',
    'field is required',
    'compensation mode',
    'server staging',
  ];

  void expectHumanMessage(Object error) {
    final message = humanReadableError(error, action: 'login');
    for (final fragment in forbiddenFragments) {
      expect(
        message,
        isNot(contains(fragment)),
        reason: 'Pesan masih mengandung teks teknis: $fragment',
      );
    }
    expect(message.trim(), isNotEmpty);
  }

  test('converts common technical errors into readable messages', () {
    expectHumanMessage(
      ApiException(
        statusCode: 500,
        message: 'HTTP 500 for POST https://absent.folony.co.id/api/auth/login',
        uri: Uri.parse('https://absent.folony.co.id/api/auth/login'),
      ),
    );
    expectHumanMessage(
      ApiException(
        statusCode: 422,
        message: 'The selected compensation mode is invalid.',
        uri: Uri.parse('https://absent.folony.co.id/api/wfa'),
      ),
    );
    expectHumanMessage(
      ApiException(
        statusCode: 422,
        message:
            'The samples.1.id field is required. The samples.2.file_name field is required.',
        uri: Uri.parse('https://absent.folony.co.id/api/face/profile'),
      ),
    );
    expectHumanMessage(
      const SocketException(
        "Failed host lookup: 'absent.folony.co.id' (OS Error: No address associated with hostname, errno = 7)",
      ),
    );
    expectHumanMessage(
      const HandshakeException(
        'Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED)',
      ),
    );
    expectHumanMessage(
      const FormatException('Unexpected character (at character 1) <br />'),
    );
    expectHumanMessage(
      const HttpException('Connection closed while receiving data'),
    );
    expectHumanMessage(
      TimeoutException('after 0:00:12'),
    );
    expectHumanMessage(
      const FileSystemException('Cannot open file'),
    );
    expectHumanMessage(
      StateError('Bad state: Remote attendance write failed'),
    );
    expectHumanMessage(
      StateError('Upload foto gagal dibaca dari server staging. Respons: data'),
    );
  });
}
