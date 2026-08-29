class AppNotification {
  const AppNotification({required this.id, required this.type, required this.content, required this.isRead, required this.createdAt});

  final String id;
  final String type;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      type: map['type'] as String,
      content: map['content'] as String,
      isRead: map['is_read'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
