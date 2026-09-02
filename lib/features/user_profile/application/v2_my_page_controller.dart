import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/application/providers/auth_providers.dart';
import '../../auth/application/providers/google_auth_providers.dart';
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

  @override
  V2MyPageState build() {
    return V2MyPageState.initial(
      ref.read(authRepositoryProvider).currentSession,
    );
  }

  Future<void> refresh() async {
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

  Future<bool> reauthenticateWithPasswordForDeletion(String password) async {
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

  Future<bool> reauthenticateWithGoogleForDeletion() async {
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

  Future<bool> deleteAccount() async {
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

    state = V2MyPageState(
      session: session,
      profile: state.profile,
      failure: null,
      isLoading: false,
      isSavingDisplayName: false,
      isSigningOut: false,
      isDeletingAccount: true,
    );

    final result = await ref
        .read(accountDeletionRepositoryProvider)
        .deleteAccount();

    final failure = result.failureOrNull;

    if (failure != null || result.valueOrNull != true) {
      state = V2MyPageState(
        session: authRepository.currentSession,
        profile: state.profile,
        failure:
            failure ??
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

  Future<bool> signOut() async {
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
