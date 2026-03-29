import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'auth_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider authProvider) async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    final bool success = _isRegisterMode
        ? await authProvider.registerWithEmail(
            email: email,
            password: password,
          )
        : await authProvider.signInWithEmail(
            email: email,
            password: password,
          );

    if (!mounted) return;

    if (success) {
      // ✅ AuthGate に戻して初回判定（onboarding_done フラグ）に任せる
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const AuthGate(),
        ),
      );
      return;
    }

    final String message = authProvider.errorMessage ?? 'ログインに失敗しました';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _resetPassword(AuthProvider authProvider) async {
    final String email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先にメールアドレスを入力してください')),
      );
      return;
    }

    final bool success = await authProvider.sendPasswordResetEmail(email);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'パスワード再設定メールを送信しました'
              : (authProvider.errorMessage ?? '送信に失敗しました'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (BuildContext context, AuthProvider authProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('ログイン'),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '自販機ナビ',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isRegisterMode
                                  ? 'アカウントを作成して始めましょう'
                                  : 'アカウントにログインして続けます',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const <String>[AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'メールアドレス',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (String? value) {
                                final String text = (value ?? '').trim();
                                if (text.isEmpty) {
                                  return 'メールアドレスを入力してください';
                                }
                                if (!text.contains('@')) {
                                  return 'メールアドレスの形式を確認してください';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: _isRegisterMode
                                  ? const <String>[AutofillHints.newPassword]
                                  : const <String>[AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'パスワード',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (String? value) {
                                final String text = (value ?? '').trim();
                                if (text.isEmpty) {
                                  return 'パスワードを入力してください';
                                }
                                if (text.length < 6) {
                                  return '6文字以上で入力してください';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () => _submit(authProvider),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Text(
                                        _isRegisterMode ? '登録してはじめる' : 'ログイン'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isRegisterMode = !_isRegisterMode;
                                      });
                                    },
                              child: Text(
                                _isRegisterMode
                                    ? 'すでにアカウントをお持ちの方はこちら'
                                    : 'アカウントを新規作成する',
                              ),
                            ),
                            TextButton(
                              onPressed: authProvider.isLoading
                                  ? null
                                  : () => _resetPassword(authProvider),
                              child: const Text('パスワードを忘れた場合'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
