import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/image_picker_service.dart';
import '../../../routes/app_routes.dart';
import '../../../shared_widgets/app_drawer.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_sessions_drawer.dart';
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
  File? _attachedPhoto;
  bool _sending = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала прикрепите фото')),
      );
      return;
    }

    setState(() => _sending = true);
    final error = await ref
        .read(chatControllerProvider.notifier)
        .sendPhotoWithPrompt(photo: photo, promptText: prompt);
    setState(() {
      _sending = false;
      _attachedPhoto = null;
    });

    if (error != null && mounted) {
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
  }

  void _startNewChat() {
    ref.read(chatControllerProvider.notifier).startNewChat();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatControllerProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      endDrawer: const ChatSessionsDrawer(),
      appBar: AppBar(
        title: const Text('AI Hairstyle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Новый чат',
            onPressed: _startNewChat,
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.forum_outlined),
              tooltip: 'Мои чаты',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Прикрепите фото и опишите желаемую причёску или '
                        'бороду — я сгенерирую несколько вариантов.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      MessageBubble(message: messages[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Ошибка: $error')),
            ),
          ),
          PromptInputBar(
            attachedPhoto: _attachedPhoto,
            onAttachPhoto: _attachPhoto,
            onRemovePhoto: () => setState(() => _attachedPhoto = null),
            onSend: _send,
            sending: _sending,
          ),
        ],
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
