import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/theme_controller.dart';

/// MVP settings screen: currently just theme mode. More settings (language,
/// notifications, etc.) will be added here later.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeModeAsync = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: themeModeAsync.when(
        data: (currentMode) => RadioGroup<ThemeMode>(
          groupValue: currentMode,
          onChanged: (value) {
            if (value != null) {
              ref.read(themeControllerProvider.notifier).setThemeMode(value);
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Тема оформления',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                secondary: Icon(Icons.brightness_auto_outlined),
                title: Text('Как в системе'),
              ),
              const RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                secondary: Icon(Icons.light_mode_outlined),
                title: Text('Светлая'),
              ),
              const RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                secondary: Icon(Icons.dark_mode_outlined),
                title: Text('Тёмная'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка: $error')),
      ),
    );
  }
}
