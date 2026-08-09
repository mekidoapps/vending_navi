import '../../../core/errors/app_failure.dart';

final class GoogleAuthState {
  const GoogleAuthState({this.isLoading = false, this.failure});

  final bool isLoading;
  final AppFailure? failure;
}

enum GoogleAuthActionResult { authenticated, cancelled, failed }
