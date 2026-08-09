import '../../../core/errors/app_failure.dart';

enum EmailAuthAction { signIn, register, passwordReset, signOut }

final class EmailAuthState {
  const EmailAuthState({
    this.isLoading = false,
    this.failure,
    this.lastCompletedAction,
  });

  final bool isLoading;
  final AppFailure? failure;
  final EmailAuthAction? lastCompletedAction;

  EmailAuthState copyWith({
    bool? isLoading,
    AppFailure? failure,
    bool clearFailure = false,
    EmailAuthAction? lastCompletedAction,
    bool clearLastCompletedAction = false,
  }) {
    return EmailAuthState(
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
      lastCompletedAction: clearLastCompletedAction
          ? null
          : lastCompletedAction ?? this.lastCompletedAction,
    );
  }
}
