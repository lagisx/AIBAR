import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/error_translator.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/models/subscription.dart';
import '../../../data/services/image_picker_service.dart';
import '../../../routes/app_routes.dart';
import '../../../shared_widgets/app_drawer.dart';
import '../../generation_settings/controllers/generation_settings_controller.dart';
import '../../style_presets/controllers/variant_count_controller.dart';
import '../../style_presets/data/style_presets_data.dart';
import '../../style_presets/models/style_preset.dart';
import '../../style_presets/widgets/style_presets_sheet.dart';
import '../../subscription/controllers/subscription_controller.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_skeleton_loader.dart';
import '../widgets/message_bubble.dart';
import '../widgets/prompt_input_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _imagePickerService = ImagePickerService();
  final _scrollController = ScrollController();
  final _promptBarKey = GlobalKey<PromptInputBarState>();
  File? _attachedPhoto;
  bool _sending = false;
  String? _regeneratingMessageId;
  int _sendToken = 0;
  final Set<String> _selectedStyleIds = {};

  List<StylePreset> get _selectedStyles =>
      stylePresets.where((p) => _selectedStyleIds.contains(p.id)).toList();

  void _openStylePresets() {
    final variantCount =
        ref.read(variantCountControllerProvider).valueOrNull ?? 1;
    showStylePresetsSheet(
      context,
      selectedIds: _selectedStyleIds,
      variantCount: variantCount,
      onVariantCountChanged: (count) =>
          ref.read(variantCountControllerProvider.notifier).setCount(count),
      onToggle: (preset) => setState(() {
        if (!_selectedStyleIds.remove(preset.id)) {
          _selectedStyleIds.add(preset.id);
        }
      }),
    );
  }

  String _composeFinalPrompt(String userPrompt) {
    final styles = _selectedStyles.map((p) => p.promptText).join(', ');
    if (styles.isEmpty) return userPrompt;
    return '$styles. $userPrompt';
  }

  Future<void> _attachPhoto() async {
    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (source == null) return;

    final photo = source == _PhotoSource.camera
        ? await _imagePickerService.pickFromCamera()
        : await _imagePickerService.pickFromGallery();
    if (photo != null) setState(() => _attachedPhoto = photo);
  }

  Future<void> _send(String prompt) async {
    final photo = _attachedPhoto;
    if (photo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сначала прикрепите фото')));
      return;
    }

    final token = ++_sendToken;

    setState(() {
      _sending = true;
      _attachedPhoto = null;
    });
    _scrollToBottom();

    final settings = ref.read(generationSettingsControllerProvider).valueOrNull;
    final variantCount =
        ref.read(variantCountControllerProvider).valueOrNull ?? 1;
    final result = await ref
        .read(chatControllerProvider.notifier)
        .sendPhotoWithPrompt(
          photo: photo,
          promptText: _composeFinalPrompt(prompt),
          variantCount: variantCount,
          settings: settings,
        );

    if (token != _sendToken) return;

    if (result.messageSent && result.error == null) {
      await ref.read(chatControllerProvider.notifier).waitForReply();
      if (token != _sendToken) return;
      if (mounted) {
        await ref.read(chatControllerProvider.notifier).refreshMessages();
      }
    }

    if (!mounted || token != _sendToken) return;
    setState(() => _sending = false);

    if (!result.messageSent) {
      setState(() => _attachedPhoto = photo);
      _promptBarKey.currentState?.fillPrompt(prompt);
    }

    final error = result.error;
    if (error != null) _showResultError(error);
  }

  void _cancelGeneration() {
    _sendToken++;
    ref.read(chatControllerProvider.notifier).cancelGeneration();
    setState(() => _sending = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Генерация отменена')));
  }

  void _startNewChat() {
    ref.read(chatControllerProvider.notifier).startNewChat();
    setState(() => _selectedStyleIds.clear());
  }

  ({String? photoUrl, String? promptText}) _findSourceForResult(
    List<ChatMessage> messages,
    int resultIndex,
  ) {
    for (var i = resultIndex - 1; i >= 0; i--) {
      final candidate = messages[i];
      if (candidate.role == MessageRole.user && candidate.imageUrl != null) {
        return (photoUrl: candidate.imageUrl, promptText: candidate.content);
      }
    }
    return (photoUrl: null, promptText: null);
  }

  void _showResultError(String error) {
    final isLimit = error.toLowerCase().contains('лимит');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        action: isLimit
            ? SnackBarAction(
                label: 'Тарифы',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.paywall),
              )
            : null,
      ),
    );
  }

  Future<void> _regenerate(
    String messageId,
    String photoUrl,
    String promptText,
  ) async {
    setState(() => _regeneratingMessageId = messageId);

    final settings = ref.read(generationSettingsControllerProvider).valueOrNull;
    final variantCount =
        ref.read(variantCountControllerProvider).valueOrNull ?? 1;
    final result = await ref
        .read(chatControllerProvider.notifier)
        .regenerate(
          sourcePhotoUrl: photoUrl,
          promptText: promptText,
          variantCount: variantCount,
          settings: settings,
        );

    if (result.messageSent && result.error == null) {
      await ref.read(chatControllerProvider.notifier).waitForReply();
      if (mounted) {
        await ref.read(chatControllerProvider.notifier).refreshMessages();
      }
    }

    if (!mounted) return;
    setState(() => _regeneratingMessageId = null);

    final error = result.error;
    if (error != null) _showResultError(error);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatControllerProvider, (previous, next) {
      next.whenData((_) => _scrollToBottom());
    });
    final messagesAsync = ref.watch(chatControllerProvider);
    final subscription = ref.watch(subscriptionControllerProvider).valueOrNull;
    final isPro = subscription?.tier != SubscriptionTier.free;
    final hasReachedLimit =
        subscription != null &&
        subscription.requestsUsedThisPeriod >=
            (AppConstants.tierRequestLimits[subscription.tier.name] ?? 0);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('VEGAS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Новый чат',
            onPressed: _startNewChat,
          ),
        ],
      ),
      extendBody: true,
      body: Column(
        children: [
          if (hasReachedLimit)
            _LimitReachedBanner(
              subscription: subscription!,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.paywall),
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return _EmptyChatState(
                          onPromptTap: (prompt) =>
                              _promptBarKey.currentState?.fillPrompt(prompt),
                        );
                      }
                      final itemCount = messages.length + (_sending ? 1 : 0);
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 96),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return const GeneratingBubble(
                              key: ValueKey('generating'),
                            );
                          }
                          final message = messages[index];
                          final isImageResult =
                              message.type == MessageType.imageResult;
                          final source = isImageResult
                              ? _findSourceForResult(messages, index)
                              : (photoUrl: null, promptText: null);
                          return MessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                            sourcePhotoUrl: source.photoUrl,
                            isPro: isPro,
                            isRegenerating:
                                _regeneratingMessageId == message.id,
                            onRegenerate:
                                (isImageResult &&
                                    source.photoUrl != null &&
                                    source.promptText != null)
                                ? () => _regenerate(
                                    message.id,
                                    source.photoUrl!,
                                    source.promptText!,
                                  )
                                : null,
                          );
                        },
                      );
                    },
                    loading: () => const ChatSkeletonLoader(),
                    error: (error, stackTrace) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            friendlyErrorMessage(
                              error,
                              context: 'chat',
                              stackTrace: stackTrace,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(chatControllerProvider),
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedStyleIds.isNotEmpty)
                        _SelectedStylesRow(
                          styles: _selectedStyles,
                          onRemove: (preset) => setState(
                            () => _selectedStyleIds.remove(preset.id),
                          ),
                        ),
                      PromptInputBar(
                        key: _promptBarKey,
                        attachedPhoto: _attachedPhoto,
                        onAttachPhoto: _attachPhoto,
                        onRemovePhoto: () =>
                            setState(() => _attachedPhoto = null),
                        onOpenStylePresets: _openStylePresets,
                        onSend: _send,
                        sending: _sending,
                        onCancel: _cancelGeneration,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedStylesRow extends StatelessWidget {
  final List<StylePreset> styles;
  final ValueChanged<StylePreset> onRemove;

  const _SelectedStylesRow({required this.styles, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: styles.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
          itemBuilder: (context, index) {
            final preset = styles[index];
            return Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(preset.icon, size: 16),
              label: Text(preset.title, style: const TextStyle(fontSize: 12)),
              onDeleted: () => onRemove(preset),
            );
          },
        ),
      ),
    );
  }
}

const _emptyStateExamplePrompts = [
  'Сделай мне красные волосы',
  'Хочу короткую стрижку fade',
  'Добавь чёлку и лёгкие локоны',
  'Покрась волосы в пепельный блонд',
  'Сделай афро-кудри',
  'Хочу гладкий боб до плеч',
  'Добавь омбре с розовым оттенком',
  'Сделай длинные волнистые волосы',
  'Хочу дерзкий undercut',
  'Покрась волосы в платиновый блонд',
];

class _EmptyChatState extends StatefulWidget {
  final ValueChanged<String> onPromptTap;

  const _EmptyChatState({required this.onPromptTap});

  @override
  State<_EmptyChatState> createState() => _EmptyChatStateState();
}

class _EmptyChatStateState extends State<_EmptyChatState> {
  late final List<String> _shownPrompts = (List<String>.from(
    _emptyStateExamplePrompts,
  )..shuffle()).take(4).toList();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                color: colors.onPrimaryContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Новый образ начинается здесь',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Выберите идею или опишите свою',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: _shownPrompts.map((prompt) {
                return ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: colors.surfaceContainerHigh,
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                  label: Text(prompt, style: const TextStyle(fontSize: 13)),
                  onPressed: () => widget.onPromptTap(prompt),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PhotoSource { camera, gallery }

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Сделать фото'),
            onTap: () => Navigator.of(context).pop(_PhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.of(context).pop(_PhotoSource.gallery),
          ),
        ],
      ),
    );
  }
}

class _LimitReachedBanner extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onTap;

  const _LimitReachedBanner({required this.subscription, required this.onTap});

  String get _message {
    if (subscription.tier == SubscriptionTier.free) {
      return 'Лимиты закончились. Обновитесь до Pro или Max, чтобы продолжить';
    }
    return 'Вы достигли лимита. Следующее обновление ${_resetInWords(subscription.periodResetAt)}.';
  }

  static String _resetInWords(DateTime resetAt) {
    final remaining = resetAt.difference(DateTime.now());
    if (remaining.inHours <= 0) return 'уже сегодня';
    final days = (remaining.inHours / 24).ceil();
    return 'через $days ${_pluralDays(days)}';
  }

  static String _pluralDays(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_clock_outlined,
                size: 18,
                color: colors.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _message,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colors.onErrorContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}