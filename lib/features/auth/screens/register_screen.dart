import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared_widgets/primary_button.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      final hasSession =
          await ref.read(authRepositoryProvider).signUpWithEmail(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              );
      if (hasSession) {
        // Email confirmation is disabled in this Supabase project, so
        // sign-up already returned an active session. Pop back to the
        // root gate, which will pick up the new auth state and move on to
        // the consent/chat screen.
        if (mounted) Navigator.of(context).pop();
        return;
      }
      setState(() {
        _infoMessage =
            'Проверьте почту и подтвердите email, затем войдите в аккаунт.';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Не удалось зарегистрироваться: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      (value == null || !value.contains('@'))
                          ? 'Введите корректный email'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                  validator: (value) => (value == null || value.length < 6)
                      ? 'Минимум 6 символов'
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (_infoMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_infoMessage!),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Создать аккаунт',
                  onPressed: _signUp,
                  loading: _loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
