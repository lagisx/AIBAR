import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/consent/controllers/consent_controller.dart';
import 'features/consent/screens/photo_consent_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/settings/controllers/theme_controller.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/subscription/screens/paywall_screen.dart';
import 'routes/app_routes.dart';

class HairstyleAiApp extends ConsumerWidget {
  const HairstyleAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider).valueOrNull ?? ThemeMode.system;

    return MaterialApp(
      title: 'AI Hairstyle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const RootGate(),
      routes: {
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.paywall: (_) => const PaywallScreen(),
        AppRoutes.profile: (_) => const ProfileScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
      },
    );
  }
}

/// Decides which top-level screen to show:
/// not signed in -> Login, signed in without consent -> PhotoConsent,
/// otherwise -> Chat.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const LoginScreen();
    }

    final consentAsync = ref.watch(consentControllerProvider);
    return consentAsync.when(
      data: (accepted) => accepted ? const ChatScreen() : const PhotoConsentScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Ошибка: $error')),
      ),
    );
  }
}
