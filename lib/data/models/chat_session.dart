class ChatSession {
  final String id;
  final String userId;
  final String? title;
  final DateTime createdAt;
  final DateTime lastMessageAt;

  const ChatSession({
    required this.id,
    required this.userId,
    this.title,
    required this.createdAt,
    required this.lastMessageAt,
  });

  String get displayTitle => (title == null || title!.trim().isEmpty)
      ? 'Новый чат'
      : title!;

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastMessageAt: DateTime.parse(map['last_message_at'] as String),
    );
  }
}
