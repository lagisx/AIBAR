import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/config/app_constants.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/ai_generation_service.dart';
import '../services/supabase_service.dart';

class ChatRepository {
  final AiGenerationService _aiGenerationService = AiGenerationService();
  final _uuid = const Uuid();

  static const int messagePageSize = 50;

  String get _userId {
    final id = SupabaseService.currentUser?.id;
    if (id == null) throw Exception('Пользователь не авторизован');
    return id;
  }

  Stream<List<ChatSession>> watchSessions() {
    return SupabaseService.client
        .from(AppConstants.chatSessionsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('last_message_at', ascending: false)
        .map((rows) => rows.map(ChatSession.fromMap).toList());
  }

  /// Loads the most recent page of messages in a session. Pass [before] to
  /// load an older page (infinite scroll) instead of re-fetching everything.
  Future<List<ChatMessage>> fetchMessages(
    String sessionId, {
    DateTime? before,
  }) async {
    var query = SupabaseService.client
        .from(AppConstants.chatMessagesTable)
        .select()
        .eq('session_id', sessionId);

    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(messagePageSize);

    return (rows as List)
        .map((row) => ChatMessage.fromMap(row as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  Stream<ChatMessage> watchNewMessages(String sessionId) {
    final seenIds = <String>{};
    return SupabaseService.client
        .from(AppConstants.chatMessagesTable)
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at')
        .map((rows) => rows.map(ChatMessage.fromMap).toList())
        .expand((messages) => messages)
        .where((message) => seenIds.add(message.id));
  }

  Future<String> uploadSourcePhoto(File photo) async {
    final path = '$_userId/${_uuid.v4()}.jpg';
    await SupabaseService.client.storage
        .from(AppConstants.sourcePhotosBucket)
        .upload(path, photo);
    return SupabaseService.client.storage
        .from(AppConstants.sourcePhotosBucket)
        .getPublicUrl(path);
  }

  Future<ChatSession> _createSession(String firstPromptText) async {
    const maxTitleLength = 60;
    final title = firstPromptText.length > maxTitleLength
        ? '${firstPromptText.substring(0, maxTitleLength)}…'
        : firstPromptText;

    final row = await SupabaseService.client
        .from(AppConstants.chatSessionsTable)
        .insert({'user_id': _userId, 'title': title})
        .select()
        .single();
    return ChatSession.fromMap(row);
  }

  /// Sends a photo + prompt. If [sessionId] is null this is the first
  /// message of a new conversation, so a `chat_sessions` row is created
  /// right here — a session never appears in the sessions list before the
  /// user has actually written something in it.
  ///
  /// Returns the session id the message was sent into.
  Future<String> sendGenerationRequest({
    required File photo,
    required String promptText,
    String? sessionId,
  }) async {
    final session =
        sessionId ?? (await _createSession(promptText)).id;
    final photoUrl = await uploadSourcePhoto(photo);

    final messageRow = await SupabaseService.client
        .from(AppConstants.chatMessagesTable)
        .insert({
          'user_id': _userId,
          'session_id': session,
          'role': 'user',
          'type': 'image_prompt',
          'content': promptText,
          'image_url': photoUrl,
        })
        .select()
        .single();

    await SupabaseService.client.from(AppConstants.generationRequestsTable).insert({
      'user_id': _userId,
      'message_id': messageRow['id'],
      'prompt_text': promptText,
      'source_photo_url': photoUrl,
      'status': 'pending',
    });

    await _aiGenerationService.requestGeneration(
      sourcePhotoUrl: photoUrl,
      promptText: promptText,
      messageId: messageRow['id'] as String,
      sessionId: session,
    );

    return session;
  }
}
