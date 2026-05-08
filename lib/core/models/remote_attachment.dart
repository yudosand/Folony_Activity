class RemoteAttachment {
  const RemoteAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.url,
    this.thumbnailUrl,
    this.sizeInBytes,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final String url;
  final String? thumbnailUrl;
  final int? sizeInBytes;

  factory RemoteAttachment.fromJson(Map<String, dynamic> json) {
    return RemoteAttachment(
      id: json['id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      sizeInBytes: json['size_in_bytes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'mime_type': mimeType,
      'url': url,
      'thumbnail_url': thumbnailUrl,
      'size_in_bytes': sizeInBytes,
    };
  }
}
