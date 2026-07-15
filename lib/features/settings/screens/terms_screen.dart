import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Условия использования')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Text(
          'Пользуясь AI Hairstyle, вы соглашаетесь на обработку загруженных '
          'фотографий для генерации причёсок и бороды. Фото хранятся '
          'ограниченное время и удаляются автоматически.\n\n'
          'Полный текст условий использования и политики конфиденциальности '
          'будет добавлен перед публичным запуском приложения.',
        ),
      ),
    );
  }
}
