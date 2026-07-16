import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/error_translator.dart';
import '../../../data/models/subscription.dart';
import '../../../routes/app_routes.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../settings/controllers/theme_controller.dart';
import '../../subscription/controllers/subscription_controller.dart';
import '../controllers/gender_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _pickGender(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final gender = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'male',
              groupValue: current,
              title: const Text('Мужской'),
              secondary: const Icon(Icons.male),
              onChanged: (value) => Navigator.of(context).pop(value),
            ),
            RadioListTile<String>(
              value: 'female',
              groupValue: current,
              title: const Text('Женский'),
              secondary: const Icon(Icons.female),
              onChanged: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
      ),
    );
    if (gender != null) {
      await ref.read(genderControllerProvider.notifier).setGender(gender);
    }
  }

  Future<void> _confirmClearAllChats(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить все чаты?'),
        content: const Text(
          'Вся история переписки будет удалена безвозвратно. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Очистить',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(chatControllerProvider.notifier).clearAllChats();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Все чаты удалены')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось очистить чаты: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Все чаты, фото и избранное будут удалены безвозвратно. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Удалить',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить аккаунт: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final subscriptionAsync = ref.watch(subscriptionControllerProvider);
    final themeModeAsync = ref.watch(themeControllerProvider);
    final genderAsync = ref.watch(genderControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль и настройки')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(user?.email ?? '—'),
          ),
          subscriptionAsync.when(
            data: (subscription) => Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Тариф'),
                  subtitle: Text(subscription.tier.name.toUpperCase()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.paywall),
                ),
                _RequestsRemainingTile(subscription: subscription),
              ],
            ),
            loading: () => const ListTile(title: Text('Загрузка тарифа...')),
            error: (e, stackTrace) => ListTile(
              title: Text(
                friendlyErrorMessage(
                  e,
                  context: 'profile',
                  stackTrace: stackTrace,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wc_outlined),
            title: const Text('Пол'),
            subtitle: Text(switch (genderAsync.valueOrNull) {
              'male' => 'Мужской',
              'female' => 'Женский',
              _ => 'Не указан',
            }),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickGender(context, ref, genderAsync.valueOrNull),
          ),
          const Divider(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Тема оформления',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          themeModeAsync.when(
            data: (currentMode) => Column(
              children: [
                _ThemeOption(
                  label: 'Как в системе',
                  icon: Icons.brightness_auto_outlined,
                  mode: ThemeMode.system,
                  groupValue: currentMode,
                ),
                _ThemeOption(
                  label: 'Светлая',
                  icon: Icons.light_mode_outlined,
                  mode: ThemeMode.light,
                  groupValue: currentMode,
                ),
                _ThemeOption(
                  label: 'Тёмная',
                  icon: Icons.dark_mode_outlined,
                  mode: ThemeMode.dark,
                  groupValue: currentMode,
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                friendlyErrorMessage(
                  error,
                  context: 'theme_settings',
                  stackTrace: stackTrace,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Данные',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: Icon(
              Icons.delete_sweep_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Очистить все чаты',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Удалить всю историю переписки'),
            onTap: () => _confirmClearAllChats(context, ref),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Выйти'),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: TextButton(
              onPressed: () => _confirmDeleteAccount(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: const Text('Удалить аккаунт'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _RequestsRemainingTile extends ConsumerStatefulWidget {
  final Subscription subscription;

  const _RequestsRemainingTile({required this.subscription});

  @override
  ConsumerState<_RequestsRemainingTile> createState() =>
      _RequestsRemainingTileState();
}

class _RequestsRemainingTileState
    extends ConsumerState<_RequestsRemainingTile> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Пересчитываем текст обратного отсчёта раз в минуту, без похода в сеть.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _pluralDays(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }

  static String _pluralHours(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'часов';
    if (mod10 == 1) return 'час';
    if (mod10 >= 2 && mod10 <= 4) return 'часа';
    return 'часов';
  }

  static String _pluralMinutes(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'минут';
    if (mod10 == 1) return 'минута';
    if (mod10 >= 2 && mod10 <= 4) return 'минуты';
    return 'минут';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _resetLabel(DateTime resetAt) {
    final now = DateTime.now();
    final remaining = resetAt.difference(now);

    if (remaining.isNegative) return 'Лимит обновится с минуты на минуту';

    final time =
        '${_twoDigits(resetAt.hour)}:${_twoDigits(resetAt.minute)}';
    final isToday =
        resetAt.year == now.year &&
        resetAt.month == now.month &&
        resetAt.day == now.day;

    if (remaining.inDays >= 1) {
      final days = remaining.inDays;
      return 'Обновится через $days ${_pluralDays(days)}';
    }
    if (remaining.inHours >= 1) {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      final relative = minutes == 0
          ? '$hours ${_pluralHours(hours)}'
          : '$hours ${_pluralHours(hours)} $minutes ${_pluralMinutes(minutes)}';
      return isToday
          ? 'Обновится через $relative (сегодня в $time)'
          : 'Обновится через $relative (в $time)';
    }
    final minutes = remaining.inMinutes.clamp(1, 59);
    return 'Обновится через $minutes ${_pluralMinutes(minutes)}';
  }

  @override
  Widget build(BuildContext context) {
    final subscription = widget.subscription;
    final limit =
        AppConstants.tierRequestLimits[subscription.tier.name] ?? 1;
    final used = subscription.requestsUsedThisPeriod.clamp(0, limit);
    final percent = (used / limit * 100).round();
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Использовано запросов: $percent%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => ref.invalidate(subscriptionControllerProvider),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.refresh,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _resetLabel(subscription.periodResetAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends ConsumerWidget {
  final String label;
  final IconData icon;
  final ThemeMode mode;
  final ThemeMode groupValue;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.mode,
    required this.groupValue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: groupValue,
      onChanged: (value) {
        if (value != null) {
          ref.read(themeControllerProvider.notifier).setThemeMode(value);
        }
      },
      secondary: Icon(icon),
      title: Text(label),
    );
  }
}