import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route.dart';
import '../../../app/theme/v2_color_tokens.dart';
import '../../../app/theme/v2_radius.dart';
import '../../../app/theme/v2_spacing.dart';
import '../../../core/ui/buttons/v2_primary_button.dart';
import '../application/email_auth_controller.dart';

final class V2EmailAuthScreen extends ConsumerStatefulWidget {
  const V2EmailAuthScreen({super.key, this.onAuthenticated});

  final VoidCallback? onAuthenticated;

  @override
  ConsumerState<V2EmailAuthScreen> createState() => _V2EmailAuthScreenState();
}

final class _V2EmailAuthScreenState extends ConsumerState<V2EmailAuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

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

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();

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
    final colors = V2ColorTokens.of(context);

    return Scaffold(
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: V2Spacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ModeButton(
                        key: const Key('emailLoginMode'),
                        label: 'ログイン',
                        selected: !_isRegisterMode,
                        onPressed: authState.isLoading
                            ? null
                            : () => _changeMode(false),
                      ),
                    ),
                    const SizedBox(width: V2Spacing.sm),
                    Expanded(
                      child: _ModeButton(
                        key: const Key('emailRegisterMode'),
                        label: '新規登録',
                        selected: _isRegisterMode,
                        onPressed: authState.isLoading
                            ? null
                            : () => _changeMode(true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: V2Spacing.lg),
                TextField(
                  key: const Key('emailField'),
                  controller: _emailController,
                  enabled: !authState.isLoading,
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
                  enabled: !authState.isLoading,
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
                      onPressed: authState.isLoading
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
                    enabled: !authState.isLoading,
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
                  onPressed: authState.isLoading ? null : _submit,
                ),
                if (!_isRegisterMode) ...<Widget>[
                  const SizedBox(height: V2Spacing.sm),
                  TextButton(
                    key: const Key('passwordResetButton'),
                    onPressed: authState.isLoading ? null : _resetPassword,
                    child: const Text('パスワードを忘れた場合'),
                  ),
                ],
                const SizedBox(height: V2Spacing.md),
                Text(
                  'Googleログインは次の実装段階でこの画面に追加します。',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
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
  const _FailureCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = V2ColorTokens.of(context);

    return DecoratedBox(
      key: const Key('emailAuthFailure'),
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
          ],
        ),
      ),
    );
  }
}
