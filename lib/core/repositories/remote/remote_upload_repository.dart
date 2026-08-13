import '../../models/remote_attachment.dart';
import '../../network/simple_api_client.dart';
import '../upload_repository.dart';

class RemoteUploadRepository implements UploadRepository {
  const RemoteUploadRepository({
    required SimpleApiClient client,
  }) : _client = client;

  final SimpleApiClient _client;

  @override
  Future<RemoteAttachment> uploadAttachment({
    required String filePath,
    String? label,
  }) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      final response = await _client.postMultipart(
        '/uploads/attachments',
        fileField: 'file',
        filePath: filePath,
        fields: {
          if (label != null && label.isNotEmpty) 'label': label,
        },
      );

      final attachment = RemoteAttachment.fromJson(_unwrapMap(response));
      if (attachment.hasRequiredPayload) {
        return attachment;
      }

      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }

    throw StateError(
      'Foto sudah dikirim, tapi respons server belum lengkap.',
    );
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
