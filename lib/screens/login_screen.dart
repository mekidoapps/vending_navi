import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginMode {
  signIn,
  signUp,
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  _LoginMode _mode = _LoginMode.signIn;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  bool get _isSignIn => _mode == _LoginMode.signIn;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final validationMessage = _validate(email: email, password: password);
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isSignIn) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showMessage(_mapFirebaseAuthError(e));
    } catch (e) {
      _showMessage('ログイン処理に失敗しました: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String? _validate({
    required String email,
    required String password,
  }) {
    if (email.isEmpty) {
      return 'メールアドレスを入力してください。';
    }

    if (!_looksLikeEmail(email)) {
      return 'メールアドレスの形式を確認してください。';
    }

    if (password.isEmpty) {
      return 'パスワードを入力してください。';
    }

    if (!_isSignIn && password.length < 6) {
      return 'パスワードは6文字以上にしてください。';
    }

    return null;
  }

  bool _looksLikeEmail(String email) {
    return email.contains('@') && email.contains('.');
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'user-disabled':
        return 'このアカウントは無効化されています。';
      case 'user-not-found':
        return 'このメールアドレスのアカウントが見つかりません。';
      case 'wrong-password':
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが違います。';
      case 'email-already-in-use':
        return 'このメールアドレスはすでに使われています。';
      case 'weak-password':
        return 'パスワードが弱すぎます。6文字以上にしてください。';
      case 'operation-not-allowed':
        return 'メール/パスワードログインが有効になっていません。';
      case 'too-many-requests':
        return '試行回数が多すぎます。少し時間をおいてからお試しください。';
      case 'network-request-failed':
        return '通信に失敗しました。ネットワーク状況を確認してください。';
      default:
        return e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : '認証に失敗しました。';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _switchMode(_LoginMode mode) {
    if (_isSubmitting) return;

    setState(() {
      _mode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignIn ? 'ログイン' : '新規登録';
    final buttonLabel = _isSignIn ? 'ログインする' : '新規登録する';
    final subtitle = _isSignIn
        ? '登録済みのメールアドレスでログインします。'
        : 'メールアドレスとパスワードでアカウントを作成します。';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '自販機ナビ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60707A),
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'ログイン',
                            selected: _isSignIn,
                            onTap: () => _switchMode(_LoginMode.signIn),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModeButton(
                            label: '新規登録',
                            selected: !_isSignIn,
                            onTap: () => _switchMode(_LoginMode.signUp),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'メールアドレス',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'example@email.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'パスワード',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      enabled: !_isSubmitting,
                      obscureText: _obscurePassword,
                      autofillHints: _isSignIn
                          ? const [AutofillHints.password]
                          : const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: _isSignIn ? 'パスワードを入力' : '6文字以上で入力',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
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
                    if (!_isSignIn) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '新規登録時は6文字以上のパスワードをおすすめします。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF60707A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Icon(
                          _isSignIn
                              ? Icons.login_rounded
                              : Icons.person_add_alt_1_rounded,
                        ),
                        label: Text(_isSubmitting ? '処理中…' : buttonLabel),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ログインするとできること',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF334148),
                      ),
                    ),
                    SizedBox(height: 10),
                    _BulletRow(text: '自販機の登録'),
                    _BulletRow(text: 'お気に入りドリンクの保存'),
                    _BulletRow(text: '通知設定の利用'),
                    _BulletRow(text: '経験値・称号の保存'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text('あとで'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF6FF) : const Color(0xFFF7FBFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFE3E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF334148),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Color(0xFF60707A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF60707A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE3E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}