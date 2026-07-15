import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/settings/screens/terms_screen.dart';
import '../routes/app_routes.dart';

Future<void> showAccountMenu(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Профиль'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).pushNamed(AppRoutes.profile);
            },
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Тарифы'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).pushNamed(AppRoutes.paywall);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Настройки'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).pushNamed(AppRoutes.settings);
            },
          ),
          ListTile(
            leading: const Icon(Icons.more_horiz),
            title: const Text('Прочее'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _showMoreMenu(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    ),
  );
}

void _showMoreMenu(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Условия использования'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              );
            },
          ),
        ],
      ),
    ),
  );
}
