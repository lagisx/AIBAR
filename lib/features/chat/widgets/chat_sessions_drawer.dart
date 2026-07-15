import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../controllers/chat_controller.dart';

class ChatSessionsDrawer extends ConsumerWidget {
  const ChatSessionsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(chatSessionsProvider);
    // Also watch the chat state so the highlighted session updates when the
    // user switches conversations (currentSessionId itself isn't watchable).
    ref.watch(chatControllerProvider);
    final activeSessionId = ref.read(chatControllerProvider.notifier).currentSessionId;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Чаты', style: Theme.of(context).textTheme.titleLarge),
            ),
            const Divider(height: 1),
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) {
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
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(
                          session.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          DateFormat('d MMM, HH:mm', 'ru').format(session.lastMessageAt),
                        ),
                        selected: session.id == activeSessionId,
                        onTap: () {
                          Navigator.of(context).pop();
                          ref.read(chatControllerProvider.notifier).openSession(session.id);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Ошибка: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
