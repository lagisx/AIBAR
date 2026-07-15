import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_session.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/services/ai_generation_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final chatSessionsProvider = StreamProvider<List<ChatSession>>((ref) {
  return ref.watch(chatRepositoryProvider).watchSessions();
});

final chatControllerProvider =
    AsyncNotifierProvider<ChatController, List<ChatMessage>>(
        ChatController.new);

/// Holds the messages of whichever conversation is currently open.
/// `currentSessionId == null` means an unsaved "new chat" — nothing has
/// been sent in it yet, so it doesn't exist in `chat_sessions`.
class ChatController extends AsyncNotifier<List<ChatMessage>> {
  String? _sessionId;
  StreamSubscription<ChatMessage>? _subscription;

  String? get currentSessionId => _sessionId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<List<ChatMessage>> build() async {
    ref.onDispose(() => _subscription?.cancel());
    return [];
  }

  void startNewChat() {
    _subscription?.cancel();
    _sessionId = null;
    state = const AsyncData([]);
  }

  Future<void> openSession(String sessionId) async {
    _subscription?.cancel();
    _sessionId = sessionId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.fetchMessages(sessionId));
    _listenForNewMessages(sessionId);
  }

  void _listenForNewMessages(String sessionId) {
    _subscription = _repo.watchNewMessages(sessionId).listen((message) {
      final current = state.valueOrNull ?? [];
      if (current.any((m) => m.id == message.id)) return;
      state = AsyncData([...current, message]);
    });
  }

  Future<String?> sendPhotoWithPrompt({
    required File photo,
    required String promptText,
  }) async {
    try {
      final wasNewSession = _sessionId == null;
      final sessionId = await _repo.sendGenerationRequest(
        photo: photo,
        promptText: promptText,
        sessionId: _sessionId,
      );

      if (wasNewSession) {
        _sessionId = sessionId;
        _listenForNewMessages(sessionId);
        // Fetch once so the just-sent message shows up immediately instead
        // of waiting on the realtime stream, which only starts listening
        // after the insert above already happened.
        state = await AsyncValue.guard(() => _repo.fetchMessages(sessionId));
      }
      return null;
    } on GenerationLimitExceededException catch (e) {
      return e.message;
    } catch (e) {
      return 'Не удалось отправить запрос: $e';
    }
  }
}
