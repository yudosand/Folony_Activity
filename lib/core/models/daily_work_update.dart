class DailyWorkUpdate {
  const DailyWorkUpdate({
    required this.note,
    required this.createdAt,
    required this.startedAt,
    this.photoPath,
    this.isFinished = false,
  });

  final String note;
  final DateTime createdAt;
  final DateTime startedAt;
  final String? photoPath;
  final bool isFinished;

  factory DailyWorkUpdate.fromJson(Map<String, dynamic> json) =>
      DailyWorkUpdate(
        note: json['note'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
        photoPath: json['photo_url'] as String?,
        isFinished: json['is_finished'] == true,
      );
}
