import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: themeModeAsync.when(
        data: (currentMode) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Тема оформления',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка: $error')),
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
