import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/auth/data/dto/auth_user_dto.dart';
import 'package:vending_app/features/auth/data/repositories/google_auth_repository_impl.dart';
import 'package:vending_app/features/auth/data/sources/google_firebase_auth_client.dart';
import 'package:vending_app/features/auth/data/sources/google_sign_in_client.dart';
import 'package:vending_app/features/auth/domain/entities/google_sign_in_outcome.dart';

void main() {
  test('account chooser cancelはCancelled outcomeになる', () async {
    final repository = GoogleAuthRepositoryImpl(
      googleSignInClient: _FakeGoogleSignInClient(),
      firebaseAuthClient: _FakeGoogleFirebaseAuthClient(),
    );

    final result = await repository.signIn();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isA<GoogleSignInCancelled>());
  });

  test('Google tokenをFirebaseへ渡してDomain sessionへ変換する', () async {
    final firebase = _FakeGoogleFirebaseAuthClient();

    final repository = GoogleAuthRepositoryImpl(
      googleSignInClient: _FakeGoogleSignInClient(
        tokens: const GoogleSignInTokens(
          idToken: 'id-token',
          accessToken: 'access-token',
        ),
      ),
      firebaseAuthClient: firebase,
    );

    final result = await repository.signIn();
    final outcome = result.valueOrNull;

    expect(firebase.callCount, 1);
    expect(outcome, isA<GoogleSignInCompleted>());

    final completed = outcome! as GoogleSignInCompleted;
    expect(completed.session.userOrNull?.uid, 'google_user');
  });

  test('Platform cancel exceptionもCancelled outcomeになる', () async {
    final repository = GoogleAuthRepositoryImpl(
      googleSignInClient: _FakeGoogleSignInClient(
        error: PlatformException(code: 'sign_in_canceled'),
      ),
      firebaseAuthClient: _FakeGoogleFirebaseAuthClient(),
    );

    final result = await repository.signIn();

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull, isA<GoogleSignInCancelled>());
  });

  test('FirebaseAuthExceptionはFailureになる', () async {
    final repository = GoogleAuthRepositoryImpl(
      googleSignInClient: _FakeGoogleSignInClient(
        tokens: const GoogleSignInTokens(
          idToken: 'id-token',
          accessToken: null,
        ),
      ),
      firebaseAuthClient: _FakeGoogleFirebaseAuthClient(
        error: FirebaseAuthException(code: 'network-request-failed'),
      ),
    );

    final result = await repository.signIn();

    expect(result.isFailure, isTrue);
  });
}

final class _FakeGoogleSignInClient implements GoogleSignInClient {
  _FakeGoogleSignInClient({this.tokens, this.error});

  final GoogleSignInTokens? tokens;
  final Object? error;

  @override
  Future<GoogleSignInTokens?> signIn() async {
    final value = error;
    if (value != null) {
      throw value;
    }
    return tokens;
  }
}

final class _FakeGoogleFirebaseAuthClient implements GoogleFirebaseAuthClient {
  _FakeGoogleFirebaseAuthClient({this.error});

  final Object? error;
  int callCount = 0;

  @override
  Future<AuthUserDto> signInWithTokens(GoogleSignInTokens tokens) async {
    callCount += 1;

    final value = error;
    if (value != null) {
      throw value;
    }

    return AuthUserDto(
      uid: 'google_user',
      email: 'google@example.com',
      displayName: 'Google User',
      providerIds: const <String>['google.com'],
      emailVerified: true,
    );
  }
}
