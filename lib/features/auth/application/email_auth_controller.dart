import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/result/app_result.dart';
import '../domain/entities/auth_session.dart';
import '../domain/services/email_auth_validator.dart';
import 'email_auth_state.dart';
import 'providers/auth_providers.dart';

final emailAuthControllerProvider =
    NotifierProvider<EmailAuthController, EmailAuthState>(
      EmailAuthController.new,
      name: 'emailAuthControllerProvider',
    );

final class EmailAuthController extends Notifier<EmailAuthState> {
  @override
  EmailAuthState build() {
    return const EmailAuthState();
  }

  Future<bool> signIn({required String email, required String password}) async {
    final validation = _validateCredentials(email: email, password: password);
    if (validation != null) {
      _setFailure(validation);
      return false;
    }

    final normalizedEmail = EmailAuthValidator.normalizeEmail(email);

    state = const EmailAuthState(isLoading: true);

    final result = await ref
        .read(authRepositoryProvider)
        .signInWithEmail(email: normalizedEmail, password: password);

    return _completeSession(result, EmailAuthAction.signIn);
  }

  Future<bool> register({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final validation =
        _validateCredentials(email: email, password: password) ??
        EmailAuthValidator.validateConfirmation(
          password: password,
          confirmation: passwordConfirmation,
        );

    if (validation != null) {
      _setFailure(validation);
      return false;
    }

    final normalizedEmail = EmailAuthValidator.normalizeEmail(email);

    state = const EmailAuthState(isLoading: true);

    final result = await ref
        .read(authRepositoryProvider)
        .registerWithEmail(email: normalizedEmail, password: password);

    return _completeSession(result, EmailAuthAction.register);
  }

  Future<bool> sendPasswordReset({required String email}) async {
    final validation = EmailAuthValidator.validateEmail(email);
    if (validation != null) {
      _setFailure(validation);
      return false;
    }

    state = const EmailAuthState(isLoading: true);

    final result = await ref
        .read(authRepositoryProvider)
        .sendPasswordResetEmail(
          email: EmailAuthValidator.normalizeEmail(email),
        );

    return result.fold(
      onSuccess: (_) {
        state = const EmailAuthState(
          lastCompletedAction: EmailAuthAction.passwordReset,
        );
        return true;
      },
      onFailure: (failure) {
        _setFailure(failure);
        return false;
      },
    );
  }

  Future<bool> signOut() async {
    state = const EmailAuthState(isLoading: true);

    final result = await ref.read(authRepositoryProvider).signOut();

    return _completeSession(result, EmailAuthAction.signOut);
  }

  void clearFailure() {
    if (state.failure == null) {
      return;
    }
    state = state.copyWith(clearFailure: true);
  }

  AppFailure? _validateCredentials({
    required String email,
    required String password,
  }) {
    return EmailAuthValidator.validateEmail(email) ??
        EmailAuthValidator.validatePassword(password);
  }

  bool _completeSession(AppResult<AuthSession> result, EmailAuthAction action) {
    return result.fold(
      onSuccess: (_) {
        state = EmailAuthState(lastCompletedAction: action);
        return true;
      },
      onFailure: (failure) {
        _setFailure(failure);
        return false;
      },
    );
  }

  void _setFailure(AppFailure failure) {
    state = EmailAuthState(failure: failure);
  }
}
