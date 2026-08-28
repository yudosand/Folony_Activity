class FaqItem {
  const FaqItem({
    required this.id,
    required this.title,
    required this.body,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String body;
  final int sortOrder;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
