import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/content_blocking/application/blocked_content_state.dart';

void main() {
  group('blockedContentProvider', () {
    test(
      'loads safe blocked IDs and entries after guest-to-auth transition',
      () async {
        final sessions = StreamController<AuthSession>.broadcast();
        final gateway = _FakeGateway(
          reads: <Future<Object?>>[_value(_response('a'))],
        );
        final container = _container(sessions, gateway);
        addTearDown(container.dispose);
        addTearDown(sessions.close);
        _listen(container);

        sessions.add(const GuestAuthSession());
        await _settle();
        expect(container.read(blockedContentProvider).machineIds, isEmpty);
        expect(gateway.readCount, 0);

        sessions.add(_session('a'));
        await _settle();
        final state = container.read(blockedContentProvider);
        expect(state.machineIds, <String>{'machine_a'});
        expect(state.photoIds, <String>{'photo_a'});
        expect(state.productIds, <String>{'product_a'});
        expect(state.blocks.single.handle, 'block_a');
        expect(state.blocks.single.targetType, 'photo');
        expect(gateway.readCount, 1);
      },
    );

    test(
      'clears A immediately and keeps only B when accounts switch',
      () async {
        final sessions = StreamController<AuthSession>.broadcast();
        final first = Completer<Object?>();
        final second = Completer<Object?>();
        final gateway = _FakeGateway(
          reads: <Future<Object?>>[first.future, second.future],
        );
        final container = _container(sessions, gateway);
        addTearDown(container.dispose);
        addTearDown(sessions.close);
        _listen(container);

        sessions.add(_session('a'));
        await _settle();
        sessions.add(_session('b'));
        await _settle();
        expect(container.read(blockedContentProvider).machineIds, isEmpty);

        second.complete(_response('b'));
        await _settle();
        first.complete(_response('a'));
        await _settle();

        final state = container.read(blockedContentProvider);
        expect(state.machineIds, <String>{'machine_b'});
        expect(state.photoIds, <String>{'photo_b'});
        expect(state.productIds, <String>{'product_b'});
        expect(state.blocks.single.handle, 'block_b');
      },
    );

    test(
      'clears state without another read on logout or account deletion state',
      () async {
        final sessions = StreamController<AuthSession>.broadcast();
        final gateway = _FakeGateway(
          reads: <Future<Object?>>[_value(_response('a'))],
        );
        final container = _container(sessions, gateway);
        addTearDown(container.dispose);
        addTearDown(sessions.close);
        _listen(container);

        sessions.add(_session('a'));
        await _settle();
        expect(container.read(blockedContentProvider).machineIds, isNotEmpty);

        sessions.add(const GuestAuthSession());
        await _settle();
        expect(container.read(blockedContentProvider).machineIds, isEmpty);
        expect(gateway.readCount, 1);

        // Account deletion is surfaced to the app by the same authenticated-to-guest
        // session transition, so it must also leave no private block state behind.
        sessions.add(_session('b'));
        await _settle();
        sessions.add(const GuestAuthSession());
        await _settle();
        expect(container.read(blockedContentProvider).blocks, isEmpty);
      },
    );

    test('uses an empty state when the private callable read fails', () async {
      final sessions = StreamController<AuthSession>.broadcast();
      final failure = Completer<Object?>();
      final gateway = _FakeGateway(reads: <Future<Object?>>[failure.future]);
      final container = _container(sessions, gateway);
      addTearDown(container.dispose);
      addTearDown(sessions.close);
      _listen(container);

      sessions.add(_session('a'));
      await _settle();
      failure.completeError(StateError('private'));
      await _settle();
      final state = container.read(blockedContentProvider);
      expect(state.machineIds, isEmpty);
      expect(state.photoIds, isEmpty);
      expect(state.productIds, isEmpty);
      expect(state.blocks, isEmpty);
    });

    test(
      'refresh after block and unblock replaces state with server response',
      () async {
        final sessions = StreamController<AuthSession>.broadcast();
        final gateway = _FakeGateway(
          reads: <Future<Object?>>[
            _value(_response('old')),
            _value(_response('new')),
            _value(const <String, Object?>{}),
          ],
        );
        final container = _container(sessions, gateway);
        addTearDown(container.dispose);
        addTearDown(sessions.close);
        _listen(container);

        sessions.add(_session('a'));
        await _settle();
        final controller = container.read(blockedContentProvider.notifier);

        expect(
          await controller.block(
            targetType: 'machine',
            machineId: 'machine_new',
          ),
          isTrue,
        );
        expect(container.read(blockedContentProvider).machineIds, <String>{
          'machine_new',
        });
        expect(gateway.operations.single.operation, 'blockContentSource');

        expect(await controller.unblockHandle('block_new'), isTrue);
        final state = container.read(blockedContentProvider);
        expect(state.machineIds, isEmpty);
        expect(state.blocks, isEmpty);
        expect(gateway.operations.last.operation, 'unblockContentSource');
      },
    );

    test('stores only safe block handles and content identifiers', () async {
      final sessions = StreamController<AuthSession>.broadcast();
      final gateway = _FakeGateway(
        reads: <Future<Object?>>[
          _value(<String, Object?>{
            'machineIds': <String>['machine_safe'],
            'blocks': <Object?>[
              <String, Object?>{
                'handle': 'block_safe',
                'kind': 'content',
                'targetType': 'machine',
                'machineId': 'machine_safe',
                'actorUid': 'must-not-be-modelled',
                'email': 'must-not-be-modelled@example.invalid',
                'storagePath': 'must-not-be-modelled',
              },
            ],
          }),
        ],
      );
      final container = _container(sessions, gateway);
      addTearDown(container.dispose);
      addTearDown(sessions.close);
      _listen(container);

      sessions.add(_session('a'));
      await _settle();
      final entry = container.read(blockedContentProvider).blocks.single;
      expect(entry.handle, 'block_safe');
      expect(entry.kind, 'content');
      expect(entry.targetType, 'machine');
      expect(entry.machineId, 'machine_safe');
      expect(entry.photoId, isNull);
      expect(entry.productId, isNull);
    });
  });
}

ProviderContainer _container(
  StreamController<AuthSession> sessions,
  BlockedContentGateway gateway,
) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(sessions.stream),
      ),
      blockedContentGatewayProvider.overrideWithValue(gateway),
    ],
  );
}

void _listen(ProviderContainer container) {
  container.listen<BlockedContentState>(
    blockedContentProvider,
    (_, _) {},
    fireImmediately: true,
  );
}

Future<Object?> _value(Object? value) => Future<Object?>.value(value);

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

AuthenticatedAuthSession _session(String uid) => AuthenticatedAuthSession(
  AuthUser(
    uid: uid,
    email: null,
    displayName: null,
    providerIds: const <String>['password'],
    emailVerified: true,
  ),
);

Map<String, Object?> _response(String suffix) => <String, Object?>{
  'machineIds': <String>['machine_$suffix'],
  'photoIds': <String>['photo_$suffix'],
  'productIds': <String>['product_$suffix'],
  'blocks': <Object?>[
    <String, Object?>{
      'handle': 'block_$suffix',
      'kind': 'content',
      'targetType': 'photo',
      'machineId': 'machine_$suffix',
      'photoId': 'photo_$suffix',
    },
  ],
};

final class _FakeGateway implements BlockedContentGateway {
  _FakeGateway({required List<Future<Object?>> reads})
    : _reads = Queue<Future<Object?>>.of(reads);

  final Queue<Future<Object?>> _reads;
  final List<_Operation> operations = <_Operation>[];
  var readCount = 0;

  @override
  Future<void> change({
    required String operation,
    required Map<String, Object?> data,
  }) async {
    operations.add(_Operation(operation, data));
  }

  @override
  Future<Object?> getBlockedContentIds() {
    readCount += 1;
    if (_reads.isEmpty) return Future<Object?>.value(const <String, Object?>{});
    return _reads.removeFirst();
  }

  @override
  Future<Object?> resolveContentBlockMode(Map<String, Object?> data) =>
      Future<Object?>.value(const <String, Object?>{'blockMode': 'content'});
}

final class _Operation {
  const _Operation(this.operation, this.data);

  final String operation;
  final Map<String, Object?> data;
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._sessions);

  final Stream<AuthSession> _sessions;

  @override
  AuthSession get currentSession => const GuestAuthSession();

  @override
  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<bool>> reauthenticateWithPassword({
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> signOut() => throw UnimplementedError();

  @override
  Stream<AuthSession> watchSession() => _sessions;
}
