import '../../../core/errors/app_failure.dart';
import '../../auth/domain/entities/auth_session.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../domain/entities/user_profile.dart';

final class V2MyPageState {
  const V2MyPageState({
    required this.session,
    required this.profile,
    required this.failure,
    required this.isLoading,
    required this.isSavingDisplayName,
    required this.isSigningOut,
  });

  factory V2MyPageState.initial(AuthSession session) {
    return V2MyPageState(
      session: session,
      profile: null,
      failure: null,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
    );
  }

  final AuthSession session;
  final UserProfile? profile;
  final AppFailure? failure;
  final bool isLoading;
  final bool isSavingDisplayName;
  final bool isSigningOut;

  bool get isAuthenticated => session.isAuthenticated;

  AuthUser? get user => session.userOrNull;

  String get resolvedDisplayName {
    final stored = profile?.storedDisplayName?.trim();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final authName = user?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      return authName;
    }

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      final at = email.indexOf('@');
      if (at > 0) {
        return email.substring(0, at);
      }
      return email;
    }

    return 'ユーザー';
  }

  String get editableDisplayName {
    final stored = profile?.storedDisplayName?.trim();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final authName = user?.displayName?.trim();
    return authName ?? '';
  }
}
