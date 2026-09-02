import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/auth/data/dto/auth_user_dto.dart';
import 'package:vending_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vending_app/features/auth/data/sources/auth_data_source.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';

void main() {
  test('currentUserがnullなら現在sessionはGuest', () {
    final source = _FakeAuthDataSource();

    final repository = AuthRepositoryImpl(source);

    expect(repository.currentSession, isA<GuestAuthSession>());
  });

  test('currentUserがあれば現在sessionをDomain userへ変換する', () {
    final source = _FakeAuthDataSource(current: _userDto());

    final repository = AuthRepositoryImpl(source);

    final session = repository.currentSession;

    expect(session, isA<AuthenticatedAuthSession>());

    expect(session.userOrNull?.uid, 'user_123');

    expect(session.userOrNull?.hasProvider('password'), isTrue);
  });

  test('authStateChangesをGuest/Auth sessionへ変換して流す', () async {
    final source = _FakeAuthDataSource();

    addTearDown(source.dispose);

    final repository = AuthRepositoryImpl(source);

    final emitted = <AuthSession>[];

    final subscription = repository.watchSession().listen(emitted.add);

    addTearDown(subscription.cancel);

    source.emit(_userDto());
    source.emit(null);

    await Future<void>.delayed(Duration.zero);

    expect(emitted, hasLength(2));

    expect(emitted.first, isA<AuthenticatedAuthSession>());

    expect(emitted.last, isA<GuestAuthSession>());
  });

  test('password reauthentication is delegated', () async {
    final source = _FakeAuthDataSource(current: _userDto());

    final repository = AuthRepositoryImpl(source);

    final result = await repository.reauthenticateWithPassword(
      password: 'secret',
    );

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isTrue);
    expect(source.reauthenticationCount, 1);
    expect(source.lastPassword, 'secret');
  });
}

AuthUserDto _userDto() {
  return AuthUserDto(
    uid: 'user_123',
    email: 'user@example.com',
    displayName: 'Test User',
    providerIds: const <String>['password'],
    emailVerified: false,
  );
}

final class _FakeAuthDataSource implements AuthDataSource {
  _FakeAuthDataSource({AuthUserDto? current}) : _current = current;

  final StreamController<AuthUserDto?> _controller =
      StreamController<AuthUserDto?>.broadcast(sync: true);

  AuthUserDto? _current;

  int reauthenticationCount = 0;
  String? lastPassword;

  @override
  AuthUserDto? get currentUser => _current;

  @override
  Stream<AuthUserDto?> authStateChanges() {
    return _controller.stream;
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
  }) async {
    reauthenticationCount += 1;
    lastPassword = password;
  }

  @override
  Future<void> signOut() async {
    _current = null;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  void emit(AuthUserDto? user) {
    _current = user;
    _controller.add(user);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
