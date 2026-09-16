import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:folony_activity/core/network/simple_api_client.dart';

void main() {
  for (final multipart in [false, true]) {
    test('reads the entire delayed ${multipart ? 'upload' : 'heatmap'} response before closing HTTP', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final temp = await Directory.systemTemp.createTemp('folony-http-test-');
      addTearDown(() async {
        await server.close(force: true);
        await temp.delete(recursive: true);
      });
      final payload = jsonEncode({'data': List.generate(300, (i) => {'id': i, 'name': 'Lokasi $i'})});
      server.listen((request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        request.response.write(payload.substring(0, 30));
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        request.response.write(payload.substring(30));
        await request.response.close();
      });
      final client = SimpleApiClient(baseUrl: 'http://127.0.0.1:${server.port}/api');
      final file = await File('${temp.path}/photo.jpg').writeAsBytes([1, 2, 3]);
      final response = multipart
          ? await client.postMultipart('/uploads/attachments', fileField: 'file', filePath: file.path)
          : await client.get('/heat-map');
      expect(response['data'], hasLength(300));
      expect(response['data'].last['id'], 299);
    });
  }
}
