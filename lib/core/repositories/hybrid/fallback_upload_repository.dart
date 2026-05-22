import '../../models/remote_attachment.dart';
import '../upload_repository.dart';
import 'workflow_repository_mode.dart';

class FallbackUploadRepository implements UploadRepository {
  const FallbackUploadRepository({
    required this.mode,
    required UploadRepository remote,
    required UploadRepository local,
  })  : _remote = remote,
        _local = local;

  final WorkflowRepositoryMode mode;
  final UploadRepository _remote;
  final UploadRepository _local;

  @override
  Future<RemoteAttachment> uploadAttachment({
    required String filePath,
    String? label,
  }) async {
    if (mode == WorkflowRepositoryMode.mockOnly) {
      return _local.uploadAttachment(filePath: filePath, label: label);
    }
    return _remote.uploadAttachment(filePath: filePath, label: label);
  }
}
