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
    final response = await _client.postMultipart(
      '/uploads/attachments',
      fileField: 'file',
      filePath: filePath,
      fields: {
        if (label != null && label.isNotEmpty) 'label': label,
      },
    );
    return RemoteAttachment.fromJson(_unwrapMap(response));
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
