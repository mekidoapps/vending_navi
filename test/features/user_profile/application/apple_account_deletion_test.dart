import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/apple_auth_providers.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/apple_auth_repository.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/user_profile/application/providers/user_profile_providers.dart';
import 'package:vending_app/features/user_profile/application/v2_my_page_controller.dart';
import 'package:vending_app/features/user_profile/domain/repositories/account_deletion_repository.dart';

class _Auth extends Mock implements AuthRepository {}

void main() {
  late AuthSession session;
  late List<String> events;
  late _Apple apple;
  late _Deletion deletion;
  late ProviderContainer container;
  late V2MyPageController controller;
  setUp(() {
    session = _session('apple-user');
    events = [];
    apple = _Apple(events);
    deletion = _Deletion(events);
    final auth = _Auth();
    when(() => auth.currentSession).thenAnswer((_) => session);
    when(() => auth.signOut()).thenAnswer((_) async {
      events.add('signout');
      session = const GuestAuthSession();
      return AppResult.success(session);
    });
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        authSessionChangesProvider.overrideWith((_) => const Stream.empty()),
        appleAuthRepositoryProvider.overrideWithValue(apple),
        accountDeletionRepositoryProvider.overrideWithValue(deletion),
      ],
    );
    container.listen(v2MyPageControllerProvider, (_, _) {});
    controller = container.read(v2MyPageControllerProvider.notifier);
  });
  tearDown(() => container.dispose());

  test(
    'reauthentication precedes revocation; revocation precedes deletion',
    () async {
      expect(await controller.reauthenticateWithAppleForDeletion(), isTrue);
      expect(events, ['reauth']);
      expect(await controller.deleteAccount(), isTrue);
      expect(events, ['reauth', 'revoke', 'delete', 'signout']);
      expect(
        container.read(v2MyPageControllerProvider).isAuthenticated,
        isFalse,
      );
    },
  );
  test('reauth cancellation does not revoke or delete', () async {
    apple.reauth = const AppResult.success(false);
    expect(await controller.reauthenticateWithAppleForDeletion(), isFalse);
    expect(events, ['reauth']);
    expect(container.read(v2MyPageControllerProvider).failure, isNull);
  });
  test(
    'revocation failure stops the callable and leaves account present',
    () async {
      apple.revocation = const AppResult.failure(NetworkFailure());
      expect(await controller.deleteAccount(), isFalse);
      expect(events, ['revoke']);
      final state = container.read(v2MyPageControllerProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.isDeletingAccount, isFalse);
      expect(state.failure, isA<NetworkFailure>());
    },
  );
  test(
    'server failure after revocation never reports deletion complete',
    () async {
      deletion.result = const AppResult.failure(NetworkFailure());
      expect(await controller.deleteAccount(), isFalse);
      expect(events, ['revoke', 'delete']);
      expect(
        container.read(v2MyPageControllerProvider).failure!.userMessage,
        contains('削除の完了を確認できませんでした'),
      );
      expect(session.isAuthenticated, isTrue);
    },
  );
  test('double deletion and signout during revocation are refused', () async {
    final gate = Completer<AppResult<bool>>();
    apple.pending = gate.future;
    final first = controller.deleteAccount();
    expect(await controller.deleteAccount(), isFalse);
    expect(await controller.signOut(), isFalse);
    expect(events, ['revoke']);
    gate.complete(const AppResult.success(true));
    expect(await first, isTrue);
    expect(events, ['revoke', 'delete', 'signout']);
  });
  test(
    'account changed during revocation does not delete the new account',
    () async {
      final gate = Completer<AppResult<bool>>();
      apple.pending = gate.future;
      final operation = controller.deleteAccount();
      session = _session('another-user');
      gate.complete(const AppResult.success(true));
      expect(await operation, isFalse);
      expect(events, ['revoke']);
      expect(
        container.read(v2MyPageControllerProvider).user?.uid,
        'another-user',
      );
    },
  );
  test(
    'account changed in final confirmation cannot delete another provider account',
    () async {
      expect(await controller.reauthenticateWithAppleForDeletion(), isTrue);
      session = _session('another-user', providers: ['password']);
      expect(
        await controller.deleteAccount(expectedUid: 'apple-user'),
        isFalse,
      );
      expect(events, ['reauth']);
      expect(session.userOrNull?.uid, 'another-user');
    },
  );
  test(
    'account switched during server request is not signed out afterwards',
    () async {
      final gate = Completer<AppResult<bool>>();
      deletion.pending = gate.future;
      final operation = controller.deleteAccount();
      await Future<void>.delayed(Duration.zero);
      session = _session('another-user');
      gate.complete(const AppResult.success(true));
      expect(await operation, isFalse);
      expect(events, ['revoke', 'delete']);
      expect(
        container.read(v2MyPageControllerProvider).user?.uid,
        'another-user',
      );
    },
  );
  test(
    'Apple provider on a linked account still requires revocation',
    () async {
      session = _session(
        'apple-user',
        providers: ['apple.com', 'google.com', 'password'],
      );
      expect(await controller.deleteAccount(), isTrue);
      expect(events.take(2), ['revoke', 'delete']);
    },
  );
}

AuthSession _session(
  String uid, {
  List<String> providers = const ['apple.com'],
}) => AuthenticatedAuthSession(
  AuthUser(
    uid: uid,
    email: null,
    displayName: null,
    providerIds: providers,
    emailVerified: false,
  ),
);

final class _Apple implements AppleAuthRepository {
  _Apple(this.events);
  final List<String> events;
  AppResult<bool> reauth = const AppResult.success(true);
  AppResult<bool> revocation = const AppResult.success(true);
  Future<AppResult<bool>>? pending;
  @override
  Future<AppResult<bool>> reauthenticateForDeletion() async {
    events.add('reauth');
    return reauth;
  }

  @override
  Future<AppResult<bool>> revokeForDeletion() async {
    events.add('revoke');
    return await (pending ?? Future.value(revocation));
  }

  @override
  Future<AppResult<bool>> signIn() async => const AppResult.success(true);
  @override
  void discardDeletionAuthorization() {}
}

final class _Deletion implements AccountDeletionRepository {
  _Deletion(this.events);
  final List<String> events;
  AppResult<bool> result = const AppResult.success(true);
  Future<AppResult<bool>>? pending;
  @override
  Future<AppResult<bool>> deleteAccount() async {
    events.add('delete');
    return await (pending ?? Future.value(result));
  }
}
