import 'auth_session.dart';

sealed class GoogleSignInOutcome {
  const GoogleSignInOutcome();
}

final class GoogleSignInCompleted extends GoogleSignInOutcome {
  const GoogleSignInCompleted(this.session);

  final AuthSession session;
}

final class GoogleSignInCancelled extends GoogleSignInOutcome {
  const GoogleSignInCancelled();
}
