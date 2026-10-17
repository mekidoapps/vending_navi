import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/application/providers/auth_providers.dart';
import '../../auth/application/providers/google_auth_providers.dart';
import '../../auth/application/providers/apple_auth_providers.dart';
import '../../auth/domain/entities/auth_session.dart';
import 'providers/user_profile_providers.dart';
import 'v2_my_page_state.dart';

final v2MyPageControllerProvider =
    NotifierProvider<V2MyPageController, V2MyPageState>(
      V2MyPageController.new,
      name: 'v2MyPageControllerProvider',
    );

final class V2MyPageController extends Notifier<V2MyPageState> {
  static const int maxDisplayNameLength = 30;
  bool _accountOperationInFlight = false;

  Future<bool> _runAccountOperation(Future<bool> Function() operation) async {
    if (_accountOperationInFlight) return false;
    _accountOperationInFlight = true;
    try {
      return await operation();
    } finally {
      _accountOperationInFlight = false;
    }
  }

  Future<bool> reauthenticateWithPasswordForDeletion(String password) =>
      _runAccountOperation(
        () => _reauthenticateWithPasswordForDeletion(password),
      );
  Future<bool> reauthenticateWithGoogleForDeletion() =>
      _runAccountOperation(_reauthenticateWithGoogleForDeletion);
  Future<bool> reauthenticateWithAppleForDeletion() =>
      _runAccountOperation(_reauthenticateWithAppleForDeletion);
  Future<bool> deleteAccount({String? expectedUid}) =>
      _runAccountOperation(() => _deleteAccount(expectedUid: expectedUid));
  Future<bool> signOut() => _runAccountOperation(_signOut);

  void discardAppleDeletionAuthorization() {
    if (state.user?.hasProvider('apple.com') ?? false) {
      ref.read(appleAuthRepositoryProvider).discardDeletionAuthorization();
    }
  }

  Future<bool> _reauthenticateWithAppleForDeletion() async {
    final auth = ref.read(authRepositoryProvider);
    final session = auth.currentSession;
    final uid = session.userOrNull?.uid;
    if (uid == null || !session.userOrNull!.hasProvider('apple.com')) {
      return false;
    }
    state = V2MyPageState(
      session: session,
      profile: state.profile,
      failure: null,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
      isReauthenticating: true,
    );
    final result = await ref
        .read(appleAuthRepositoryProvider)
        .reauthenticateForDeletion();
    if (!ref.mounted) return false;
    final sameUser = auth.currentSession.userOrNull?.uid == uid;
    if (!sameUser) {
      ref.read(appleAuthRepositoryProvider).discardDeletionAuthorization();
    }
    state = V2MyPageState(
      session: auth.currentSession,
      profile: sameUser ? state.profile : null,
      failure: sameUser ? result.failureOrNull : const AuthenticationFailure(),
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
    );
    return sameUser &&
        result.failureOrNull == null &&
        result.valueOrNull == true;
  }

  @override
  V2MyPageState build() {
    ref.listen<AsyncValue<AuthSession>>(authSessionChangesProvider, (_, next) {
      next.when(data: _synchronizeSession, loading: () {}, error: (_, _) {});
    });

    return V2MyPageState.initial(
      ref.read(authRepositoryProvider).currentSession,
    );
  }

  void _synchronizeSession(AuthSession session) {
    final currentUserId = state.user?.uid;
    final nextUserId = session.userOrNull?.uid;

    if (!session.isAuthenticated || currentUserId != nextUserId) {
      state = V2MyPageState.initial(session);
      return;
    }

    state = V2MyPageState(
      session: session,
      profile: state.profile,
      failure: state.failure,
      isLoading: state.isLoading,
      isSavingDisplayName: state.isSavingDisplayName,
      isSigningOut: state.isSigningOut,
      isReauthenticating: state.isReauthenticating,
      isDeletingAccount: state.isDeletingAccount,
    );
  }

  Future<void> refresh() async {
    if (_accountOperationInFlight) return;
    final authRepository = ref.read(authRepositoryProvider);
    final session = authRepository.currentSession;

    if (!session.isAuthenticated) {
      state = V2MyPageState.initial(session);
      return;
    }

    final user = session.userOrNull!;
    final previousProfile = state.profile?.uid == user.uid
        ? state.profile
        : null;

    state = V2MyPageState(
      session: session,
      profile: previousProfile,
      failure: null,
      isLoading: true,
      isSavingDisplayName: false,
      isSigningOut: false,
    );

    final result = await ref
        .read(userProfileRepositoryProvider)
        .getOrCreateProfile(uid: user.uid);

    final latestSession = authRepository.currentSession;
    if (!latestSession.isAuthenticated ||
        latestSession.userOrNull?.uid != user.uid) {
      state = V2MyPageState.initial(latestSession);
      return;
    }

    final failure = result.failureOrNull;
    if (failure != null) {
      state = V2MyPageState(
        session: latestSession,
        profile: previousProfile,
        failure: failure,
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return;
    }

    state = V2MyPageState(
      session: latestSession,
      profile: result.valueOrNull,
      failure: null,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
    );
  }

  Future<bool> saveDisplayName(String rawDisplayName) async {
    final authRepository = ref.read(authRepositoryProvider);
    final session = authRepository.currentSession;

    if (!session.isAuthenticated) {
      state = V2MyPageState(
        session: session,
        profile: null,
        failure: const AuthenticationFailure(),
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    final normalized = rawDisplayName.trim();

    if (normalized.length > maxDisplayNameLength ||
        normalized.contains(RegExp(r'[\r\n\t]'))) {
      state = V2MyPageState(
        session: session,
        profile: state.profile,
        failure: const ValidationFailure(
          field: 'displayName',
          userMessage: '表示名は30文字以内の1行で入力してください。',
        ),
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    state = V2MyPageState(
      session: session,
      profile: state.profile,
      failure: null,
      isLoading: false,
      isSavingDisplayName: true,
      isSigningOut: false,
    );

    final result = await ref
        .read(userProfileRepositoryProvider)
        .saveDisplayName(
          uid: session.userOrNull!.uid,
          displayName: normalized.isEmpty ? null : normalized,
        );

    final failure = result.failureOrNull;
    if (failure != null) {
      state = V2MyPageState(
        session: session,
        profile: state.profile,
        failure: failure,
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    state = V2MyPageState(
      session: session,
      profile: result.valueOrNull,
      failure: null,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
    );
    return true;
  }

  Future<bool> _reauthenticateWithPasswordForDeletion(String password) async {
    final authRepository = ref.read(authRepositoryProvider);
    final session = authRepository.currentSession;

    if (!session.isAuthenticated) {
      state = V2MyPageState(
        session: session,
        profile: null,
        failure: const AuthenticationFailure(),
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    if (!session.userOrNull!.hasProvider('password')) {
      state = V2MyPageState(
        session: session,
        profile: state.profile,
        failure: const ValidationFailure(
          field: 'accountDeletion',
          userMessage: 'このアカウントではパスワードによる本人確認を利用できません。',
        ),
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    if (password.isEmpty) {
      state = V2MyPageState(
        session: session,
        profile: state.profile,
        failure: const ValidationFailure(
          field: 'password',
          userMessage: 'パスワードを入力してください。',
        ),
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    state = V2MyPageState(
      session: session,
      profile: state.profile,
      failure: null,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
      isReauthenticating: true,
    );

    final result = await authRepository.reauthenticateWithPassword(
      password: password,
    );

    final failure = result.failureOrNull;

    state = V2MyPageState(
      session: authRepository.currentSession,
      profile: state.profile,
      failure: failure,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
      isReauthenticating: false,
    );

    return failure == null && result.valueOrNull == true;
  }

  Future<bool> _reauthenticateWithGoogleForDeletion() async {
    final authRepository = ref.read(authRepositoryProvider);
    final session = authRepository.currentSession;

    if (!session.isAuthenticated) {
      state = V2MyPageState(
        session: session,
        profile: null,
        failure: const AuthenticationFailure(),
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    if (!session.userOrNull!.hasProvider('google.com')) {
      state = V2MyPageState(
        session: session,
        profile: state.profile,
        failure: const ValidationFailure(
          field: 'accountDeletion',
          userMessage: 'このアカウントではGoogleによる本人確認を利用できません。',
        ),
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    state = V2MyPageState(
      session: session,
      profile: state.profile,
      failure: null,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
      isReauthenticating: true,
    );

    final result = await ref
        .read(googleAuthRepositoryProvider)
        .reauthenticate();

    final failure = result.failureOrNull;
    final completed = failure == null && result.valueOrNull == true;

    state = V2MyPageState(
      session: authRepository.currentSession,
      profile: state.profile,
      failure: failure,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
      isReauthenticating: false,
    );

    return completed;
  }

  Future<bool> _deleteAccount({String? expectedUid}) async {
    final authRepository = ref.read(authRepositoryProvider);
    final session = authRepository.currentSession;

    if (!session.isAuthenticated ||
        (expectedUid != null && session.userOrNull?.uid != expectedUid)) {
      state = V2MyPageState(
        session: session,
        profile: null,
        failure: const AuthenticationFailure(),
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    state = V2MyPageState(
      session: session,
      profile: state.profile,
      failure: null,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
      isDeletingAccount: true,
    );

    final uid = session.userOrNull!.uid;
    final usesApple = session.userOrNull!.hasProvider('apple.com');
    if (usesApple) {
      // Revoke only after the final confirmation. A failed or consumed code
      // must never proceed to deleting Firebase data.
      final revocation = await ref
          .read(appleAuthRepositoryProvider)
          .revokeForDeletion();
      if (!ref.mounted) return false;
      if (revocation.failureOrNull != null ||
          revocation.valueOrNull != true ||
          authRepository.currentSession.userOrNull?.uid != uid) {
        state = V2MyPageState(
          session: authRepository.currentSession,
          profile: state.profile,
          failure: revocation.failureOrNull ?? const AuthenticationFailure(),
          isLoading: false,
          isSavingDisplayName: false,
          isSigningOut: false,
        );
        return false;
      }
    }
    if (authRepository.currentSession.userOrNull?.uid != uid) return false;

    final result = await ref
        .read(accountDeletionRepositoryProvider)
        .deleteAccount();

    if (!ref.mounted) return false;
    if (authRepository.currentSession.userOrNull?.uid != uid) {
      state = V2MyPageState.initial(authRepository.currentSession);
      return false;
    }

    final failure = result.failureOrNull;

    if (failure != null || result.valueOrNull != true) {
      state = V2MyPageState(
        session: authRepository.currentSession,
        profile: state.profile,
        failure:
            (usesApple
                ? const ValidationFailure(
                    field: 'accountDeletion',
                    userMessage:
                        'Apple連携の取消後、削除の完了を確認できませんでした。'
                        '再ログインしてアカウントの状態を確認し、必要なら本人確認からやり直してください。',
                  )
                : failure) ??
            const ValidationFailure(
              field: 'accountDeletion',
              userMessage: 'アカウント削除を完了できませんでした。',
            ),
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
        isDeletingAccount: false,
      );
      return false;
    }

    // Server-side Auth deletion is already complete.
    // Clear the local Firebase Auth session as well.
    await authRepository.signOut();

    state = V2MyPageState.initial(const GuestAuthSession());

    return true;
  }

  Future<bool> _signOut() async {
    discardAppleDeletionAuthorization();
    final authRepository = ref.read(authRepositoryProvider);
    final session = authRepository.currentSession;

    state = V2MyPageState(
      session: session,
      profile: state.profile,
      failure: null,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: true,
    );

    final result = await authRepository.signOut();
    final failure = result.failureOrNull;

    if (failure != null) {
      state = V2MyPageState(
        session: authRepository.currentSession,
        profile: state.profile,
        failure: failure,
        isLoading: false,
        isSavingDisplayName: false,
        isSigningOut: false,
      );
      return false;
    }

    final nextSession = result.valueOrNull ?? const GuestAuthSession();
    state = V2MyPageState.initial(nextSession);
    return true;
  }

  void clearFailure() {
    state = V2MyPageState(
      session: state.session,
      profile: state.profile,
      failure: null,
      isLoading: state.isLoading,
      isSavingDisplayName: state.isSavingDisplayName,
      isSigningOut: state.isSigningOut,
      isReauthenticating: state.isReauthenticating,
      isDeletingAccount: state.isDeletingAccount,
    );
  }
}
