import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_tokens.dart';
import '../core/utils/error_translator.dart';
import '../features/auth/controllers/auth_controller.dart';
import 'scissors_logo.dart';
import '../features/chat/controllers/chat_controller.dart';
import '../features/subscription/controllers/subscription_controller.dart';
import '../routes/app_routes.dart';
import 'account_menu_sheet.dart';
import 'avatar_placeholder.dart';
import 'shimmer_box.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  final Map<String, Timer> _pendingDeletes = {};

  @override
  void dispose() {
    for (final timer in _pendingDeletes.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _deleteWithUndo(String sessionId, String title) {
    _pendingDeletes[sessionId]?.cancel();
    setState(() {
      _pendingDeletes[sessionId] = Timer(const Duration(seconds: 5), () {
        _pendingDeletes.remove(sessionId);
        ref.read(chatControllerProvider.notifier).deleteSession(sessionId);
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«$title» удалён'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () {
            _pendingDeletes.remove(sessionId)?.cancel();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final subscriptionAsync = ref.watch(subscriptionControllerProvider);
    final sessionsAsync = ref.watch(chatSessionsProvider);
    ref.watch(
      chatControllerProvider,
    );
    final activeSessionId = ref
        .read(chatControllerProvider.notifier)
        .currentSessionId;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const ScissorsLogo(size: 36),
                  const SizedBox(width: AppSpacing.md),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF7C8CF8), Color(0xFF4A55C9)],
                    ).createShader(bounds),
                    child: const Text(
                      'VEGAS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _NavItem(
                icon: Icons.star_outline,
                label: 'Избранное',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed(AppRoutes.favorites);
                },
              ),
            ),
            Padding(
  padding: const EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.xs,
  ),
  child: const Align(
    alignment: Alignment.centerLeft,
    child: _SectionLabel('Чаты'),
  ),
),
            Expanded(
              child: sessionsAsync.when(
                data: (allSessions) {
                  final sessions = allSessions
                      .where((s) => !_pendingDeletes.containsKey(s.id))
                      .toList();
                  if (sessions.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Здесь появятся ваши чаты, как только вы отправите первое сообщение.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return Padding(
                        key: ValueKey(session.id),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        child: ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.chat_bubble_outline,
                              size: 20,
                            ),
                            title: Text(
                              session.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              DateFormat(
                                'd MMM, HH:mm',
                                'ru',
                              ).format(session.lastMessageAt),
                            ),
                            selected: session.id == activeSessionId,
                            trailing: PopupMenuButton<_SessionAction>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (action) async {
                                switch (action) {
                                  case _SessionAction.rename:
                                    final newTitle = await _promptRenameSession(
                                      context,
                                      session.displayTitle,
                                    );
                                    if (newTitle != null &&
                                        newTitle.isNotEmpty) {
                                      ref
                                          .read(chatControllerProvider.notifier)
                                          .renameSession(session.id, newTitle);
                                    }
                                  case _SessionAction.delete:
                                    _deleteWithUndo(
                                      session.id,
                                      session.displayTitle,
                                    );
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: _SessionAction.rename,
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Переименовать'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: _SessionAction.delete,
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Удалить'),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              ref
                                  .read(chatControllerProvider.notifier)
                                  .openSession(session.id);
                            },
                          ),
                      );
                    },
                  );
                },
                loading: () => const _SessionsSkeletonList(),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        friendlyErrorMessage(
                          error,
                          context: 'sessions',
                          stackTrace: stackTrace,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(chatSessionsProvider),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  onTap: () => showAccountMenu(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        AvatarPlaceholder(email: user?.email, radius: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user?.email ?? 'Гость',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subscriptionAsync.when(
                                data: (subscription) => Text(
                                  'Тариф: ${subscription.tier.name.toUpperCase()}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(width: AppSpacing.md),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }
}

enum _SessionAction { rename, delete }

Future<String?> _promptRenameSession(
  BuildContext context,
  String currentTitle,
) {
  final controller = TextEditingController(text: currentTitle);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Переименовать чат'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Название чата'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

class _SessionsSkeletonList extends StatelessWidget {
  const _SessionsSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => const ListTile(
        leading: ShimmerBox(
          width: 24,
          height: 24,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        title: Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: ShimmerBox(width: 160, height: 14),
        ),
        subtitle: ShimmerBox(width: 100, height: 11),
      ),
    );
  }
}