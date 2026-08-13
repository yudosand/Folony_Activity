class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? publishedAt;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: _parseDateTime(json['published_at']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
