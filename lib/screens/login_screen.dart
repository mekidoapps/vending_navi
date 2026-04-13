import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isRegisterMode) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _message = _firebaseErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'ログインに失敗しました。\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showGoogleLoginTemporarilyUnavailable() {
    setState(() {
      _message =
      'Googleログインは現在調整中です。\n'
          'いまはメールアドレスログインを先に利用してください。';
    });
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(text)) {
      return 'メールアドレスの形式で入力してください';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'パスワードを入力してください';
    }
    if (text.length < 6) {
      return '6文字以上で入力してください';
    }
    return null;
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'このメールアドレスは既に使われています。';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'weak-password':
        return 'パスワードが弱すぎます。6文字以上にしてください。';
      case 'user-not-found':
        return 'このメールアドレスのアカウントが見つかりません。';
      case 'wrong-password':
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが違います。';
      case 'user-disabled':
        return 'このアカウントは無効化されています。';
      case 'operation-not-allowed':
        return 'メールアドレスログインが有効になっていません。Firebase設定を確認してください。';
      case 'too-many-requests':
        return '試行回数が多すぎます。少し待ってから再度お試しください。';
      case 'network-request-failed':
        return '通信に失敗しました。ネットワーク接続を確認してください。';
      default:
        return '認証に失敗しました。\n${e.message ?? e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isRegisterMode ? 'メールアドレスで新規登録' : 'メールアドレスでログイン';
    final submitLabel = _isRegisterMode ? '新規登録する' : 'ログインする';
    final switchLabel = _isRegisterMode
        ? 'すでにアカウントを持っている'
        : 'はじめて使うので新規登録する';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('ログイン'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFE3E7EB),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FF),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Icon(
                            Icons.local_drink_rounded,
                            size: 38,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ログインして使えること',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const _FeatureRow(
                          icon: Icons.add_business_rounded,
                          text: '自販機の新規登録',
                        ),
                        const SizedBox(height: 8),
                        const _FeatureRow(
                          icon: Icons.favorite_rounded,
                          text: 'お気に入り飲み物の保存',
                        ),
                        const SizedBox(height: 8),
                        const _FeatureRow(
                          icon: Icons.notifications_active_rounded,
                          text: '近くの通知を受け取る',
                        ),
                        const SizedBox(height: 8),
                        const _FeatureRow(
                          icon: Icons.emoji_events_rounded,
                          text: '利用記録や成長の保存',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFE3E7EB),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'まずはメールアドレスで使える状態にします。',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: _validateEmail,
                            decoration: InputDecoration(
                              labelText: 'メールアドレス',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            validator: _validatePassword,
                            onFieldSubmitted: (_) => _submitEmailAuth(),
                            decoration: InputDecoration(
                              labelText: 'パスワード',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _submitEmailAuth,
                              icon: _isLoading
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                                  : Icon(
                                _isRegisterMode
                                    ? Icons.person_add_alt_1_rounded
                                    : Icons.login_rounded,
                              ),
                              label: Text(
                                _isLoading ? '処理中...' : submitLabel,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                setState(() {
                                  _isRegisterMode = !_isRegisterMode;
                                  _message = null;
                                });
                              },
                              child: Text(switchLabel),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          Text(
                            'Googleでログイン',
                            style: theme.textTheme.titleSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Googleログインは現在調整中です。',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : _showGoogleLoginTemporarilyUnavailable,
                              icon: const Icon(Icons.construction_rounded),
                              label: const Text('Googleログイン（調整中）'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('今はログインしない'),
                            ),
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8EC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFFD9A8),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: Color(0xFFB26A00),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF8A5300),
                                        fontWeight: FontWeight.w600,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'メールアドレスログインを先に有効にすると、登録機能の確認を前に進めやすくなります。',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}