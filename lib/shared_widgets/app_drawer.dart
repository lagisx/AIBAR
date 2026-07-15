import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/subscription/controllers/subscription_controller.dart';
import 'account_menu_sheet.dart';
import 'avatar_placeholder.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final subscriptionAsync = ref.watch(subscriptionControllerProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            const Divider(height: 1),
            ListTile(
              leading: AvatarPlaceholder(email: user?.email, radius: 20),
              title: Text(
                user?.email ?? 'Гость',
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: subscriptionAsync.when(
                data: (subscription) =>
                    Text('Тариф: ${subscription.tier.name.toUpperCase()}'),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              onTap: () => showAccountMenu(context, ref),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
