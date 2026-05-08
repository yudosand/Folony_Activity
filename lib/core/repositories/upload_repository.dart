import '../models/remote_attachment.dart';

abstract class UploadRepository {
  Future<RemoteAttachment> uploadAttachment({
    required String filePath,
    String? label,
  });
}
