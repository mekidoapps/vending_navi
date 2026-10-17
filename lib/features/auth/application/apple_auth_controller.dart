import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import 'providers/apple_auth_providers.dart';

enum AppleAuthActionResult { authenticated, cancelled, failed }

final class AppleAuthState {
  const AppleAuthState({this.isLoading = false, this.failure});
  final bool isLoading;
  final AppFailure? failure;
}

final appleAuthControllerProvider =
    NotifierProvider<AppleAuthController, AppleAuthState>(
      AppleAuthController.new,
    );

final class AppleAuthController extends Notifier<AppleAuthState> {
  @override
  AppleAuthState build() => const AppleAuthState();

  Future<AppleAuthActionResult> signIn() async {
    if (state.isLoading) return AppleAuthActionResult.cancelled;
    state = const AppleAuthState(isLoading: true);
    final result = await ref.read(appleAuthRepositoryProvider).signIn();
    if (!ref.mounted) return AppleAuthActionResult.cancelled;
    state = AppleAuthState(failure: result.failureOrNull);
    return result.failureOrNull != null
        ? AppleAuthActionResult.failed
        : result.valueOrNull == true
        ? AppleAuthActionResult.authenticated
        : AppleAuthActionResult.cancelled;
  }

  void clearFailure() {
    if (!state.isLoading) state = const AppleAuthState();
  }
}
