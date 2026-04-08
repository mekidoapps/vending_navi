import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _ensureGoogleInitialized();

      final googleSignIn = GoogleSignIn.instance;

      await googleSignIn.signOut();

      final GoogleSignInAccount googleUser =
      await googleSignIn.authenticate(scopeHint: const <String>['email']);

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      Navigator.of(context).pop();
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _googleSignInErrorMessage(e);
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _firebaseErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'ログインに失敗しました。設定を確認してください。\n$e';
      });
    }
  }

  String _googleSignInErrorMessage(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'ログインがキャンセルされました。';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Googleログイン設定に問題があります。client_id や google-services.json を確認してください。';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'この端末ではGoogleログイン画面を表示できませんでした。';
      case GoogleSignInExceptionCode.userMismatch:
        return '前回のログイン情報と一致しませんでした。もう一度お試しください。';
      case GoogleSignInExceptionCode.unknownError:
        return 'Googleログインで不明なエラーが発生しました。';
      default:
        return 'Googleログインに失敗しました。';
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return '別のログイン方法で既に登録されているアカウントです。';
      case 'invalid-credential':
        return '認証情報が無効です。Googleログイン設定を確認してください。';
      case 'operation-not-allowed':
        return 'このログイン方法は現在無効です。Firebase設定を確認してください。';
      case 'user-disabled':
        return 'このアカウントは無効化されています。';
      case 'network-request-failed':
        return '通信に失敗しました。ネットワーク接続を確認してください。';
      default:
        return 'ログインに失敗しました。\n${e.message ?? e.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Googleでログイン',
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '閲覧だけならログインなしでも使えます。\n登録や保存系の機能を使う時にログインしてください。',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            icon: _isLoading
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              _isLoading ? 'ログイン中...' : 'Googleでログイン',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('今はログインしない'),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4F4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFFFD2D2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.error_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFFC62828),
                                      fontWeight: FontWeight.w600,
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
                  const SizedBox(height: 14),
                  Text(
                    'Googleログインが失敗する場合は、Firebase設定・SHA-1/SHA-256・package名・google-services.json を確認してください。',
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