import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

const _promptHints = [
  'Опишите причёску или бороду',
  'Например: "сделай короткий fade"',
  'Например: "добавь чёлку и локоны"',
  'Например: "покрась в пепельный блонд"',
  'Например: "хочу дерзкий undercut"',
  'Например: "сделай гладкий боб"',
  'Например: "афро-кудри и объём"',
  'Например: "омбре с розовым оттенком"',
];

class PromptInputBar extends StatefulWidget {
  final File? attachedPhoto;
  final VoidCallback onAttachPhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onOpenStylePresets;
  final ValueChanged<String> onSend;
  final bool sending;
  final VoidCallback? onCancel;

  const PromptInputBar({
    super.key,
    required this.attachedPhoto,
    required this.onAttachPhoto,
    required this.onRemovePhoto,
    required this.onOpenStylePresets,
    required this.onSend,
    required this.sending,
    this.onCancel,
  });

  @override
  State<PromptInputBar> createState() => PromptInputBarState();
}

class PromptInputBarState extends State<PromptInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;
  late final String _hintText =
      _promptHints[Random().nextInt(_promptHints.length)];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  void fillPrompt(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.attachedPhoto != null)
              _AttachedPhotoPreview(
                photo: widget.attachedPhoto!,
                onRemove: widget.onRemovePhoto,
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _BarIconButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Прикрепить фото',
                        onTap: widget.sending ? null : widget.onAttachPhoto,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(fontSize: 16, height: 1.35),
                          decoration: InputDecoration(
                            hintText: _hintText,
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            filled: false,
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 11,
                            ),
                          ),
                        ),
                      ),
                      _BarIconButton(
                        icon: Icons.auto_awesome_outlined,
                        tooltip: 'Стили и пресеты',
                        onTap: widget.sending
                            ? null
                            : widget.onOpenStylePresets,
                      ),
                      const SizedBox(width: 4),
                      _SendButton(
                        sending: widget.sending,
                        enabled: _hasText,
                        onSend: _handleSend,
                        onCancel: widget.onCancel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'ИИ может допускать ошибки',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachedPhotoPreview extends StatelessWidget {
  final File photo;
  final VoidCallback onRemove;

  const _AttachedPhotoPreview({required this.photo, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: AppSpacing.sm,
          left: AppSpacing.sm,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.file(
                photo,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: -7,
              right: -7,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.inverseSurface,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: colors.onInverseSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(
              icon,
              size: 22,
              color: onTap == null
                  ? colors.onSurfaceVariant.withValues(alpha: 0.4)
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback? onCancel;

  const _SendButton({
    required this.sending,
    required this.enabled,
    required this.onSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final Color background;
    final Color foreground;
    final IconData icon;
    final VoidCallback? onTap;
    final String tooltip;

    if (sending) {
      background = colors.errorContainer;
      foreground = colors.onErrorContainer;
      icon = Icons.stop_rounded;
      onTap = onCancel;
      tooltip = 'Остановить генерацию';
    } else {
      background = enabled
          ? colors.primary
          : colors.onSurface.withValues(alpha: 0.08);
      foreground = enabled
          ? colors.onPrimary
          : colors.onSurfaceVariant.withValues(alpha: 0.45);
      icon = Icons.arrow_upward_rounded;
      onTap = enabled ? onSend : null;
      tooltip = 'Отправить';
    }

    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle, color: background),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }
}