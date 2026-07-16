import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_lifecycle_tracker.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/error_translator.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/chat_session.dart';
import '../../../data/models/generation_settings.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/services/ai_generation_service.dart';
import '../../../data/services/local_notification_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../subscription/controllers/subscription_controller.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final chatSessionsProvider = StreamProvider<List<ChatSession>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(chatRepositoryProvider).watchSessions();
});

final chatControllerProvider =
    AsyncNotifierProvider<ChatController, List<ChatMessage>>(
      ChatController.new,
    );

class ChatController extends AsyncNotifier<List<ChatMessage>> {
  String? _sessionId;
  StreamSubscription<ChatMessage>? _subscription;
  Completer<void>? _pendingReplyCompleter;
  String? _pendingMessageId;

  String? get currentSessionId => _sessionId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<List<ChatMessage>> build() async {
    ref.watch(currentUserIdProvider);
    ref.onDispose(() => _subscription?.cancel());
    _sessionId = null;

    final lastSession = await _repo.fetchMostRecentSession();
    if (lastSession == null) return [];

    _sessionId = lastSession.id;
    final messages = await _repo.fetchMessages(lastSession.id);
    _listenForNewMessages(lastSession.id);
    return messages;
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

  Future<void> deleteSession(String sessionId) async {
    await _repo.deleteSession(sessionId);
    if (_sessionId == sessionId) {
      startNewChat();
    }
  }

  Future<void> renameSession(String sessionId, String newTitle) {
    return _repo.renameSession(sessionId, newTitle);
  }

  Future<void> clearAllChats() async {
    await _repo.deleteAllSessions();
    startNewChat();
  }

  void _listenForNewMessages(String sessionId) {
    _subscription = _repo.watchNewMessages(sessionId).listen(
      (message) {
        final current = state.valueOrNull ?? [];
        if (current.any((m) => m.id == message.id)) return;
        state = AsyncData([...current, message]);
        if (message.role == MessageRole.assistant) {
          _pendingReplyCompleter?.complete();
          if (message.type == MessageType.imageResult &&
              AppLifecycleTracker.instance.isBackgrounded) {
            LocalNotificationService.showGenerationReady();
          }
        }
      },
      onError: (Object e, StackTrace st) =>
          AppLogger.error('watch_new_messages', e, st),
    );
  }

  Future<void> waitForReply({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final completer = _pendingReplyCompleter;
    if (completer == null) return;
    await completer.future.timeout(timeout, onTimeout: () {});
  }

  Future<void> refreshMessages() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    try {
      final fresh = await _repo.refreshLatestMessages(sessionId);
      final current = state.valueOrNull ?? [];
      final merged = {for (final m in current) m.id: m};
      for (final m in fresh) {
        merged[m.id] = m;
      }
      final list = merged.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = AsyncData(list);
    } catch (e, st) {
      AppLogger.error('refresh_messages', e, st);
    }
  }

  Future<({bool messageSent, String? error})> sendPhotoWithPrompt({
    required File photo,
    required String promptText,
    int variantCount = 1,
    GenerationSettings? settings,
  }) async {
    final wasNewSession = _sessionId == null;
    final ({String sessionId, ChatMessage message, String sourcePhotoUrl}) sent;
    try {
      sent = await _repo.sendUserMessage(
        photo: photo,
        promptText: promptText,
        sessionId: _sessionId,
      );
    } catch (e, stackTrace) {
      return (
        messageSent: false,
        error: friendlyErrorMessage(
          e,
          context: 'send_user_message',
          stackTrace: stackTrace,
        ),
      );
    }

    return _afterMessageCreated(
      wasNewSession: wasNewSession,
      sessionId: sent.sessionId,
      message: sent.message,
      sourcePhotoUrl: sent.sourcePhotoUrl,
      promptText: promptText,
      variantCount: variantCount,
      settings: settings,
    );
  }

  Future<({bool messageSent, String? error})> regenerate({
    required String sourcePhotoUrl,
    required String promptText,
    int variantCount = 1,
    GenerationSettings? settings,
  }) async {
    final wasNewSession = _sessionId == null;
    final ({String sessionId, ChatMessage message}) sent;
    try {
      sent = await _repo.sendMessageWithExistingPhoto(
        photoUrl: sourcePhotoUrl,
        promptText: promptText,
        sessionId: _sessionId,
      );
    } catch (e, stackTrace) {
      return (
        messageSent: false,
        error: friendlyErrorMessage(
          e,
          context: 'regenerate',
          stackTrace: stackTrace,
        ),
      );
    }

    return _afterMessageCreated(
      wasNewSession: wasNewSession,
      sessionId: sent.sessionId,
      message: sent.message,
      sourcePhotoUrl: sourcePhotoUrl,
      promptText: promptText,
      variantCount: variantCount,
      settings: settings,
    );
  }

  Future<({bool messageSent, String? error})> _afterMessageCreated({
    required bool wasNewSession,
    required String sessionId,
    required ChatMessage message,
    required String sourcePhotoUrl,
    required String promptText,
    required int variantCount,
    GenerationSettings? settings,
  }) async {
    if (wasNewSession) {
      _sessionId = sessionId;
      _listenForNewMessages(sessionId);
    }

    final current = state.valueOrNull ?? [];
    if (!current.any((m) => m.id == message.id)) {
      state = AsyncData([...current, message]);
    }

    _pendingReplyCompleter = Completer<void>();
    _pendingMessageId = message.id;
    try {
      await _repo.requestGeneration(
        sourcePhotoUrl: sourcePhotoUrl,
        promptText: promptText,
        messageId: message.id,
        sessionId: sessionId,
        variantCount: variantCount,
        settings: settings,
      );
      ref.invalidate(subscriptionControllerProvider);
      return (messageSent: true, error: null);
    } on GenerationLimitExceededException catch (e) {
      ref.invalidate(subscriptionControllerProvider);
      return (messageSent: true, error: e.message);
    } catch (e, stackTrace) {
      return (
        messageSent: true,
        error: friendlyErrorMessage(
          e,
          context: 'generation',
          stackTrace: stackTrace,
        ),
      );
    } finally {
      _pendingMessageId = null;
    }
  }

  Future<void> cancelGeneration() async {
    final messageId = _pendingMessageId;
    if (messageId == null) return;
    try {
      await _repo.cancelGeneration(messageId);
    } catch (e, st) {
      AppLogger.error('cancel_generation', e, st);
    }
  }
}