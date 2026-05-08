import '../../models/remote_attachment.dart';
import '../upload_repository.dart';

class MockUploadRepository implements UploadRepository {
  const MockUploadRepository();

  @override
  Future<RemoteAttachment> uploadAttachment({
    required String filePath,
    String? label,
  }) async {
    return RemoteAttachment(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      fileName: label ?? filePath.split('\\').last,
      mimeType: 'image/jpeg',
      url: filePath,
      thumbnailUrl: filePath,
    );
  }
}
