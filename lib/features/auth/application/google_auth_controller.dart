import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/google_sign_in_outcome.dart';
import 'google_auth_state.dart';
import 'providers/google_auth_providers.dart';

final googleAuthControllerProvider =
    NotifierProvider<GoogleAuthController, GoogleAuthState>(
      GoogleAuthController.new,
      name: 'googleAuthControllerProvider',
    );

final class GoogleAuthController extends Notifier<GoogleAuthState> {
  @override
  GoogleAuthState build() {
    return const GoogleAuthState();
  }

  Future<GoogleAuthActionResult> signIn() async {
    state = const GoogleAuthState(isLoading: true);

    final result = await ref.read(googleAuthRepositoryProvider).signIn();

    return result.fold(
      onSuccess: (outcome) {
        state = const GoogleAuthState();

        return switch (outcome) {
          GoogleSignInCompleted() => GoogleAuthActionResult.authenticated,
          GoogleSignInCancelled() => GoogleAuthActionResult.cancelled,
        };
      },
      onFailure: (failure) {
        state = GoogleAuthState(failure: failure);
        return GoogleAuthActionResult.failed;
      },
    );
  }

  void clearFailure() {
    if (state.failure == null) {
      return;
    }

    state = const GoogleAuthState();
  }
}
