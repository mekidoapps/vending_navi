import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/auth/data/repositories/apple_auth_repository_impl.dart';
import 'package:vending_app/features/auth/data/sources/apple_auth_client.dart';

void main() {
  test(
    'Apple sign-in does not require a returned email/name; repeat login works',
    () async {
      final client = _Client()..uid = null;
      final repository = AppleAuthRepositoryImpl(client);
      expect((await repository.signIn()).valueOrNull, isTrue);
      client.uid = null; // A later session after sign-out.
      expect((await repository.signIn()).valueOrNull, isTrue);
      expect(client.signIns, 2);
    },
  );

  for (final code in ['web-context-cancelled', 'canceled']) {
    test('cancel $code is not an error and releases busy state', () async {
      final client = _Client()
        ..uid = null
        ..error = FirebaseAuthException(code: code, message: 'secret fixture');
      final repository = AppleAuthRepositoryImpl(client);
      final result = await repository.signIn();
      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull, isFalse);
      client.error = null;
      expect((await repository.signIn()).valueOrNull, isTrue);
    });
  }

  test('existing session is never switched or automatically linked', () async {
    final client = _Client();
    final result = await AppleAuthRepositoryImpl(client).signIn();
    expect(result.failureOrNull, isNotNull);
    expect(client.signIns, 0);
  });

  test(
    'credential collision tells the user to use the original provider',
    () async {
      final client = _Client()
        ..uid = null
        ..error = FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          message: 'private@example.test token-fixture',
        );
      final result = await AppleAuthRepositoryImpl(client).signIn();
      expect(result.failureOrNull!.userMessage, contains('これまで使っていた'));
      expect(
        result.failureOrNull!.userMessage,
        isNot(contains('private@example.test')),
      );
      expect(
        result.failureOrNull!.userMessage,
        isNot(contains('token-fixture')),
      );
    },
  );

  test('double tap starts just one native sign-in', () async {
    final gate = Completer<void>();
    final client = _Client()
      ..uid = null
      ..gate = gate.future;
    final repository = AppleAuthRepositoryImpl(client);
    final first = repository.signIn();
    expect((await repository.signIn()).valueOrNull, isNot(true));
    expect(client.signIns, 1);
    gate.complete();
    expect((await first).valueOrNull, isTrue);
  });

  test(
    'revocation needs a fresh, same-user code and consumes it once',
    () async {
      final client = _Client();
      final repository = AppleAuthRepositoryImpl(client);
      expect((await repository.revokeForDeletion()).failureOrNull, isNotNull);
      expect(client.revokes, 0);
      expect(
        (await repository.reauthenticateForDeletion()).valueOrNull,
        isTrue,
      );
      expect(client.revokes, 0); // Before final deletion confirmation.
      expect((await repository.revokeForDeletion()).valueOrNull, isTrue);
      expect(client.revokes, 1);
      expect((await repository.revokeForDeletion()).failureOrNull, isNotNull);
      expect(client.revokes, 1);
    },
  );

  test('cancelled confirmation discards the authorization', () async {
    final client = _Client();
    final repository = AppleAuthRepositoryImpl(client);
    await repository.reauthenticateForDeletion();
    repository.discardDeletionAuthorization();
    expect((await repository.revokeForDeletion()).failureOrNull, isNotNull);
    expect(client.revokes, 0);
  });

  test('missing authorization code fails closed', () async {
    final client = _Client()..code = null;
    final repository = AppleAuthRepositoryImpl(client);
    expect(
      (await repository.reauthenticateForDeletion()).failureOrNull,
      isNotNull,
    );
    expect((await repository.revokeForDeletion()).failureOrNull, isNotNull);
    expect(client.revokes, 0);
  });

  test('changed account while Apple UI is open fails closed', () async {
    final gate = Completer<void>();
    final client = _Client()..gate = gate.future;
    final repository = AppleAuthRepositoryImpl(client);
    final operation = repository.reauthenticateForDeletion();
    client.uid = 'another-user';
    gate.complete();
    expect((await operation).failureOrNull, isNotNull);
    expect((await repository.revokeForDeletion()).failureOrNull, isNotNull);
    expect(client.revokes, 0);
  });

  test(
    'account changed after reauthentication cannot revoke another user',
    () async {
      final client = _Client();
      final repository = AppleAuthRepositoryImpl(client);
      await repository.reauthenticateForDeletion();
      client.uid = 'another-user';
      expect((await repository.revokeForDeletion()).failureOrNull, isNotNull);
      expect(client.revokes, 0);
    },
  );
  test(
    'discard while native reauthentication is pending cannot restore a stale code',
    () async {
      final gate = Completer<void>();
      final client = _Client()..gate = gate.future;
      final repository = AppleAuthRepositoryImpl(client);
      final operation = repository.reauthenticateForDeletion();
      repository.discardDeletionAuthorization();
      gate.complete();
      expect((await operation).failureOrNull, isNotNull);
      expect((await repository.revokeForDeletion()).failureOrNull, isNotNull);
      expect(client.revokes, 0);
    },
  );

  test('expired code is not reused', () async {
    var now = DateTime.utc(2026, 10, 17);
    final client = _Client();
    final repository = AppleAuthRepositoryImpl(client, now: () => now);
    await repository.reauthenticateForDeletion();
    now = now.add(const Duration(minutes: 5));
    expect((await repository.revokeForDeletion()).failureOrNull, isNotNull);
    expect(client.revokes, 0);
  });

  test(
    'revocation failure stops deletion authorization and needs a new code',
    () async {
      final client = _Client();
      final repository = AppleAuthRepositoryImpl(client);
      await repository.reauthenticateForDeletion();
      client.error = FirebaseAuthException(code: 'network-request-failed');
      expect(
        (await repository.revokeForDeletion()).failureOrNull!.code,
        'network.unavailable',
      );
      client.error = null;
      expect((await repository.revokeForDeletion()).failureOrNull, isNotNull);
      expect(client.revokes, 1);
      await repository.reauthenticateForDeletion();
      expect((await repository.revokeForDeletion()).valueOrNull, isTrue);
    },
  );
}

final class _Client implements AppleAuthClient {
  String? uid = 'apple-user';
  String? code = 'short-lived-synthetic-code';
  Object? error;
  Future<void>? gate;
  int signIns = 0;
  int revokes = 0;
  @override
  String? get currentUid => uid;
  @override
  bool get hasAppleProvider => true;
  @override
  Future<void> signIn() async {
    signIns++;
    await gate;
    if (error != null) throw error!;
    uid = 'apple-user';
  }

  @override
  Future<String?> reauthenticate() async {
    await gate;
    if (error != null) throw error!;
    return code;
  }

  @override
  Future<void> revoke(String authorizationCode) async {
    revokes++;
    expect(authorizationCode, code);
    if (error != null) throw error!;
  }
}
