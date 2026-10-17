import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/repositories/apple_auth_repository.dart';
import '../mappers/firebase_auth_failure_mapper.dart';
import '../sources/apple_auth_client.dart';

final class AppleAuthRepositoryImpl implements AppleAuthRepository {
  AppleAuthRepositoryImpl(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppleAuthClient _client;
  final DateTime Function() _now;
  bool _busy = false;
  String? _authorizationCode;
  String? _authorizedUid;
  DateTime? _authorizedAt;
  int _authorizationGeneration = 0;

  static const _reauthRequired = ValidationFailure(
    field: 'appleReauthentication',
    userMessage: 'Appleで本人確認をやり直してから、アカウントを削除してください。',
  );

  @override
  void discardDeletionAuthorization() {
    _authorizationGeneration++;
    _authorizationCode = null;
    _authorizedUid = null;
    _authorizedAt = null;
  }

  @override
  Future<AppResult<bool>> signIn() => _run(() async {
    discardDeletionAuthorization();
    if (_client.currentUid != null) {
      return const AppResult.failure(
        ValidationFailure(
          field: 'appleSignIn',
          userMessage: 'ログイン済みです。アカウントを切り替える場合は、先にログアウトしてください。',
        ),
      );
    }
    await _client.signIn();
    if (_client.currentUid == null) {
      return const AppResult.failure(AuthenticationFailure());
    }
    return const AppResult.success(true);
  });

  @override
  Future<AppResult<bool>> reauthenticateForDeletion() => _run(() async {
    discardDeletionAuthorization();
    final generation = _authorizationGeneration;
    final uid = _client.currentUid;
    if (uid == null || !_client.hasAppleProvider) {
      return const AppResult.failure(_reauthRequired);
    }
    final code = await _client.reauthenticate();
    if (_authorizationGeneration != generation ||
        _client.currentUid != uid ||
        code == null ||
        code.isEmpty) {
      return const AppResult.failure(_reauthRequired);
    }
    // Authorization codes are short-lived, single-use and kept only in memory.
    _authorizationCode = code;
    _authorizedUid = uid;
    _authorizedAt = _now();
    return const AppResult.success(true);
  });

  @override
  Future<AppResult<bool>> revokeForDeletion() => _run(() async {
    final code = _authorizationCode;
    final uid = _authorizedUid;
    final at = _authorizedAt;
    // Consume before attempting the request: retries need fresh Apple approval.
    discardDeletionAuthorization();
    if (code == null ||
        uid == null ||
        at == null ||
        _client.currentUid != uid ||
        !_client.hasAppleProvider ||
        _now().difference(at).isNegative ||
        _now().difference(at) > const Duration(minutes: 4)) {
      return const AppResult.failure(_reauthRequired);
    }
    await _client.revoke(code);
    if (_client.currentUid != uid) {
      return const AppResult.failure(_reauthRequired);
    }
    return const AppResult.success(true);
  });

  Future<AppResult<bool>> _run(
    Future<AppResult<bool>> Function() action,
  ) async {
    if (_busy) {
      return const AppResult.failure(
        ValidationFailure(
          field: 'appleAuthentication',
          userMessage: '認証処理の完了をお待ちください。',
        ),
      );
    }
    _busy = true;
    try {
      return await action();
    } on FirebaseAuthException catch (error) {
      if (_isCancellation(error.code)) return const AppResult.success(false);
      return AppResult.failure(_failure(error.code));
    } on PlatformException catch (error) {
      if (_isCancellation(error.code)) return const AppResult.success(false);
      return const AppResult.failure(UnknownFailure());
    } catch (_) {
      return const AppResult.failure(UnknownFailure());
    } finally {
      _busy = false;
    }
  }

  static bool _isCancellation(String code) => const {
    'web-context-cancelled',
    'web-context-canceled',
    'canceled',
    'cancelled',
    'user-cancelled',
    'popup-closed-by-user',
    'sign_in_canceled',
  }.contains(code);

  static AppFailure _failure(String code) => switch (code) {
    'account-exists-with-different-credential' ||
    'credential-already-in-use' => const ValidationFailure(
      field: 'existingAccount',
      userMessage: 'すでに登録済みの場合は、これまで使っていたGoogleまたはメールでログインしてください。自動的な統合は行いません。',
    ),
    'user-mismatch' => _reauthRequired,
    'operation-not-allowed' => const ValidationFailure(
      field: 'appleConfiguration',
      userMessage: '現在Appleでのログインを利用できません。ほかのログイン方法を利用するか、時間をおいてお試しください。',
    ),
    _ => FirebaseAuthFailureMapper.fromCode(code),
  };
}
