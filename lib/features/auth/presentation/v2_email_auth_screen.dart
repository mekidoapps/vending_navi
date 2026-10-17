import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route.dart';
import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../core/ui/buttons/v2_primary_button.dart';
import '../../../core/ui/buttons/v2_secondary_button.dart';
import '../application/email_auth_controller.dart';
import '../application/google_auth_controller.dart';
import '../application/google_auth_state.dart';
import '../application/apple_auth_controller.dart';
import '../application/providers/apple_auth_providers.dart';
import 'auth_diagnostics.dart';

final class V2EmailAuthScreen extends ConsumerStatefulWidget {
  const V2EmailAuthScreen({super.key, this.onAuthenticated});

  final VoidCallback? onAuthenticated;

  @override
  ConsumerState<V2EmailAuthScreen> createState() => _V2EmailAuthScreenState();
}

final class _V2EmailAuthScreenState extends ConsumerState<V2EmailAuthScreen> {
  static const AuthDiagnostics _authDiagnostics = AuthDiagnostics();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _operationInFlight = false;

  Future<void> _runExclusive(Future<void> Function() action) async {
    if (_operationInFlight ||
        ref.read(emailAuthControllerProvider).isLoading ||
        ref.read(googleAuthControllerProvider).isLoading ||
        ref.read(appleAuthControllerProvider).isLoading) {
      return;
    }
    setState(() => _operationInFlight = true);
    ref.read(appleAuthControllerProvider.notifier).clearFailure();
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _operationInFlight = false);
      }
    }
  }

  Future<void> _submit() => _runExclusive(_submitAction);
  Future<void> _resetPassword() => _runExclusive(_resetPasswordAction);
  Future<void> _signInWithGoogle() => _runExclusive(_googleAction);
  Future<void> _signInWithApple() => _runExclusive(() async {
    FocusScope.of(context).unfocus();
    ref.read(emailAuthControllerProvider.notifier).clearFailure();
    ref.read(googleAuthControllerProvider.notifier).clearFailure();
    final result = await ref
        .read(appleAuthControllerProvider.notifier)
        .signIn();
    if (mounted && result == AppleAuthActionResult.authenticated) {
      _finishAuthenticated();
    }
  });

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submitAction() async {
    FocusScope.of(context).unfocus();

    ref.read(googleAuthControllerProvider.notifier).clearFailure();

    final controller = ref.read(emailAuthControllerProvider.notifier);

    final success = _isRegisterMode
        ? await controller.register(
            email: _emailController.text,
            password: _passwordController.text,
            passwordConfirmation: _confirmationController.text,
          )
        : await controller.signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );

    if (!mounted || !success) {
      return;
    }

    _finishAuthenticated();
  }

  Future<void> _resetPasswordAction() async {
    FocusScope.of(context).unfocus();

    ref.read(googleAuthControllerProvider.notifier).clearFailure();

    final success = await ref
        .read(emailAuthControllerProvider.notifier)
        .sendPasswordReset(email: _emailController.text);

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('パスワード再設定メールを送信しました。メールをご確認ください。')),
    );
  }

  Future<void> _googleAction() async {
    FocusScope.of(context).unfocus();

    ref.read(emailAuthControllerProvider.notifier).clearFailure();

    final result = await ref
        .read(googleAuthControllerProvider.notifier)
        .signIn();

    if (!mounted) {
      return;
    }

    if (result == GoogleAuthActionResult.authenticated) {
      _finishAuthenticated();
    }
  }

  void _finishAuthenticated() {
    final callback = widget.onAuthenticated;
    if (callback != null) {
      callback();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
      return;
    }

    context.goNamed(AppRoute.v2Foundation.name);
  }

  void _changeMode(bool registerMode) {
    ref.read(emailAuthControllerProvider.notifier).clearFailure();

    setState(() {
      _isRegisterMode = registerMode;
      _confirmationController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(emailAuthControllerProvider);
    final googleState = ref.watch(googleAuthControllerProvider);
    final appleState = ref.watch(appleAuthControllerProvider);
    final appleAvailable = ref.watch(appleSignInAvailableProvider);
    final colors = V2ColorTokens.of(context);
    final isBusy =
        _operationInFlight ||
        authState.isLoading ||
        googleState.isLoading ||
        appleState.isLoading;

    return PopScope(
      canPop: !isBusy,
      child: Scaffold(
        appBar: AppBar(title: const Text('ログイン / 新規登録')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(V2Spacing.lg),
                children: <Widget>[
                  Text(
                    _isRegisterMode ? 'メールで新規登録' : 'メールでログイン',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: V2Spacing.xs),
                  Text(
                    '地図の閲覧や検索はログインしなくても利用できます。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: V2Spacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ModeButton(
                          key: const Key('emailLoginMode'),
                          label: 'ログイン',
                          selected: !_isRegisterMode,
                          onPressed: isBusy ? null : () => _changeMode(false),
                        ),
                      ),
                      const SizedBox(width: V2Spacing.sm),
                      Expanded(
                        child: _ModeButton(
                          key: const Key('emailRegisterMode'),
                          label: '新規登録',
                          selected: _isRegisterMode,
                          onPressed: isBusy ? null : () => _changeMode(true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: V2Spacing.lg),
                  TextField(
                    key: const Key('emailField'),
                    controller: _emailController,
                    enabled: !isBusy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      hintText: 'example@example.com',
                    ),
                    onChanged: (_) => ref
                        .read(emailAuthControllerProvider.notifier)
                        .clearFailure(),
                  ),
                  const SizedBox(height: V2Spacing.md),
                  TextField(
                    key: const Key('passwordField'),
                    controller: _passwordController,
                    enabled: !isBusy,
                    obscureText: _obscurePassword,
                    textInputAction: _isRegisterMode
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autofillHints: <String>[
                      _isRegisterMode
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      helperText: _isRegisterMode ? '6文字以上で入力してください' : null,
                      suffixIcon: IconButton(
                        key: const Key('togglePasswordVisibility'),
                        onPressed: isBusy
                            ? null
                            : () {
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
                    onSubmitted: _isRegisterMode ? null : (_) => _submit(),
                    onChanged: (_) => ref
                        .read(emailAuthControllerProvider.notifier)
                        .clearFailure(),
                  ),
                  if (_isRegisterMode) ...<Widget>[
                    const SizedBox(height: V2Spacing.md),
                    TextField(
                      key: const Key('passwordConfirmationField'),
                      controller: _confirmationController,
                      enabled: !isBusy,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.newPassword],
                      decoration: const InputDecoration(labelText: 'パスワード（確認）'),
                      onSubmitted: (_) => _submit(),
                      onChanged: (_) => ref
                          .read(emailAuthControllerProvider.notifier)
                          .clearFailure(),
                    ),
                  ],
                  if (authState.failure != null) ...<Widget>[
                    const SizedBox(height: V2Spacing.md),
                    _FailureCard(
                      title: authState.failure!.userTitle,
                      message: authState.failure!.userMessage,
                      diagnosticCode: _authDiagnostics.codeForDisplay(
                        authState.failure!,
                      ),
                    ),
                  ],
                  const SizedBox(height: V2Spacing.lg),
                  V2PrimaryButton(
                    key: const Key('emailAuthSubmit'),
                    label: _isRegisterMode ? 'メールで登録する' : 'メールでログイン',
                    icon: _isRegisterMode
                        ? Icons.person_add_alt_1_rounded
                        : Icons.login_rounded,
                    isLoading: authState.isLoading,
                    onPressed: isBusy ? null : _submit,
                  ),
                  if (!_isRegisterMode) ...<Widget>[
                    const SizedBox(height: V2Spacing.sm),
                    TextButton(
                      key: const Key('passwordResetButton'),
                      onPressed: isBusy ? null : _resetPassword,
                      child: const Text('パスワードを忘れた場合'),
                    ),
                  ],
                  const SizedBox(height: V2Spacing.lg),
                  Row(
                    children: <Widget>[
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: V2Spacing.sm,
                        ),
                        child: Text(
                          'または',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: V2Spacing.md),
                  V2SecondaryButton(
                    key: const Key('googleAuthButton'),
                    label: googleState.isLoading ? 'Googleで処理中…' : 'Googleで続ける',
                    icon: Icons.account_circle_outlined,
                    onPressed: isBusy ? null : _signInWithGoogle,
                  ),
                  if (googleState.failure != null) ...<Widget>[
                    const SizedBox(height: V2Spacing.md),
                    _FailureCard(
                      cardKey: const Key('googleAuthFailure'),
                      title: googleState.failure!.userTitle,
                      message: googleState.failure!.userMessage,
                    ),
                  ],
                  if (appleAvailable) ...<Widget>[
                    const SizedBox(height: V2Spacing.md),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        key: const Key('appleAuthButton'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isBusy ? null : _signInWithApple,
                        icon: const Icon(Icons.apple),
                        label: Text(
                          appleState.isLoading ? 'Appleで処理中…' : 'Appleでサインイン',
                        ),
                      ),
                    ),
                    const SizedBox(height: V2Spacing.sm),
                    const Text(
                      '以前Googleやメールで登録した方は、同じ方法でログインしてください。'
                      'Appleで新たに始めても、以前の投稿やお気に入りは自動で統合されません。\n'
                      'Appleの「メールを非公開」も利用できます。次回も同じApple Accountでログインしてください。',
                    ),
                    if (appleState.failure != null) ...<Widget>[
                      const SizedBox(height: V2Spacing.md),
                      _FailureCard(
                        cardKey: const Key('appleAuthFailure'),
                        title: appleState.failure!.userTitle,
                        message: appleState.failure!.userMessage,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return FilledButton(onPressed: onPressed, child: Text(label));
    }

    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

final class _FailureCard extends StatelessWidget {
  const _FailureCard({
    this.cardKey = const Key('emailAuthFailure'),
    required this.title,
    required this.message,
    this.diagnosticCode,
  });

  final Key cardKey;
  final String title;
  final String message;
  final String? diagnosticCode;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      key: cardKey,
      decoration: BoxDecoration(
        color: colors.surfaceTint,
        borderRadius: V2Radius.control,
        border: Border.all(color: colors.error.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(V2Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: V2Spacing.xs),
            Text(message),
            if (diagnosticCode != null) ...<Widget>[
              const SizedBox(height: V2Spacing.xs),
              Text(
                '診断コード: $diagnosticCode',
                key: const Key('emailAuthDiagnosticCode'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
