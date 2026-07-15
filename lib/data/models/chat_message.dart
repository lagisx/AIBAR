import 'dart:convert';

enum MessageRole { user, assistant }

enum MessageType { text, imagePrompt, imageResult }

MessageRole _roleFromString(String value) =>
    MessageRole.values.firstWhere((r) => r.name == value);

MessageType _typeFromString(String value) {
  switch (value) {
    case 'text':
      return MessageType.text;
    case 'image_prompt':
      return MessageType.imagePrompt;
    case 'image_result':
      return MessageType.imageResult;
    default:
      return MessageType.text;
  }
}

String messageTypeToString(MessageType type) {
  switch (type) {
    case MessageType.text:
      return 'text';
    case MessageType.imagePrompt:
      return 'image_prompt';
    case MessageType.imageResult:
      return 'image_result';
  }
}

class ChatMessage {
  final String id;
  final String userId;
  final String sessionId;
  final MessageRole role;
  final MessageType type;
  final String? content;
  final String? imageUrl;
  final List<String> resultUrls;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.role,
    required this.type,
    this.content,
    this.imageUrl,
    this.resultUrls = const [],
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    final type = _typeFromString(map['type'] as String);
    final content = map['content'] as String?;

    // For assistant `image_result` messages the Edge Function stores the
    // generated image URLs as a JSON array in `content` (chat_messages has
    // no array column, unlike generation_requests.result_urls).
    List<String> resultUrls = const [];
    if (type == MessageType.imageResult && content != null) {
      try {
        resultUrls = (jsonDecode(content) as List).cast<String>();
      } catch (_) {
        resultUrls = const [];
      }
    }

    return ChatMessage(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      sessionId: map['session_id'] as String,
      role: _roleFromString(map['role'] as String),
      type: type,
      content: type == MessageType.imageResult ? null : content,
      imageUrl: map['image_url'] as String?,
      resultUrls: resultUrls,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
