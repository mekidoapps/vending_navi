import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/data/dto/auth_user_dto.dart';
import 'package:vending_app/features/auth/data/sources/auth_data_source.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';

void main() {
  test('AuthDataSourceをoverrideして現在sessionを取得できる', () {
    final source = _FakeAuthDataSource(current: _userDto());
    addTearDown(source.dispose);

    final container = ProviderContainer(
      overrides: [authDataSourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);

    final session = container.read(authCurrentSessionProvider);

    expect(session, isA<AuthenticatedAuthSession>());
    expect(session.userOrNull?.uid, 'provider_user');
  });

  test('authSessionChangesProviderが現在の認証状態を最初に流す', () async {
    final source = _FakeAuthDataSource(current: _userDto());
    addTearDown(source.dispose);

    final container = ProviderContainer(
      overrides: [authDataSourceProvider.overrideWithValue(source)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      authSessionChangesProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);

    final session = await container.read(authSessionChangesProvider.future);

    expect(session, isA<AuthenticatedAuthSession>());
    expect(session.userOrNull?.uid, 'provider_user');
  });
}

AuthUserDto _userDto() {
  return AuthUserDto(
    uid: 'provider_user',
    email: null,
    displayName: null,
    providerIds: const <String>['google.com'],
    emailVerified: false,
  );
}

final class _FakeAuthDataSource implements AuthDataSource {
  _FakeAuthDataSource({AuthUserDto? current}) : _current = current;

  final StreamController<AuthUserDto?> _controller =
      StreamController<AuthUserDto?>.broadcast(sync: true);

  AuthUserDto? _current;

  @override
  AuthUserDto? get currentUser => _current;

  @override
  Stream<AuthUserDto?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AuthUserDto> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _current ?? _userDto();
  }

  @override
  Future<AuthUserDto> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return _current ?? _userDto();
  }

  @override
  Future<void> reauthenticateWithEmailPassword({
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    _current = null;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  void emit(AuthUserDto? value) {
    _current = value;
    _controller.add(value);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
