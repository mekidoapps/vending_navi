import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vending_app/features/auth/data/sources/firebase_apple_auth_client.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

class _Credential extends Mock implements UserCredential {}

class _Info extends Mock implements AdditionalUserInfo {}

class _Provider extends Mock implements UserInfo {}

void main() {
  setUpAll(() => registerFallbackValue(AppleAuthProvider()));
  late _Auth auth;
  late _User user;
  late _Credential credential;
  late _Info info;
  late FirebaseAppleAuthClient client;
  setUp(() {
    auth = _Auth();
    user = _User();
    credential = _Credential();
    info = _Info();
    final provider = _Provider();
    when(() => provider.providerId).thenReturn('apple.com');
    when(() => user.uid).thenReturn('apple-user');
    when(() => user.providerData).thenReturn([provider]);
    when(() => auth.currentUser).thenReturn(user);
    when(() => credential.user).thenReturn(user);
    when(() => credential.additionalUserInfo).thenReturn(info);
    when(() => info.authorizationCode).thenReturn('fresh-synthetic-code');
    when(
      () => user.getIdToken(true),
    ).thenAnswer((_) async => 'synthetic-id-token');
    client = FirebaseAppleAuthClient(auth);
  });
  test(
    'sign-in uses native provider and tolerates missing email/name',
    () async {
      when(
        () => auth.signInWithProvider(any()),
      ).thenAnswer((_) async => credential);
      await client.signIn();
      final provider = verify(
        () => auth.signInWithProvider(captureAny()),
      ).captured.single;
      expect(provider, isA<AppleAuthProvider>());
      verifyNever(() => user.linkWithProvider(any()));
    },
  );
  test(
    'reauthenticates the current user rather than signing in another user',
    () async {
      when(
        () => user.reauthenticateWithProvider(any()),
      ).thenAnswer((_) async => credential);
      expect(await client.reauthenticate(), 'fresh-synthetic-code');
      verify(() => user.getIdToken(true)).called(1);
      verifyNever(() => auth.signInWithProvider(any()));
    },
  );
  test(
    'missing authorization code remains missing for repository to reject',
    () async {
      when(() => info.authorizationCode).thenReturn(null);
      when(
        () => user.reauthenticateWithProvider(any()),
      ).thenAnswer((_) async => credential);
      expect(await client.reauthenticate(), isNull);
    },
  );
  test(
    'changed Firebase user stops reauthentication before refreshing token',
    () async {
      when(() => user.reauthenticateWithProvider(any())).thenAnswer((_) async {
        when(() => auth.currentUser).thenReturn(null);
        return credential;
      });
      await expectLater(
        client.reauthenticate(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'user-mismatch',
          ),
        ),
      );
      verifyNever(() => user.getIdToken(true));
    },
  );
  test('revocation delegates only the one-time authorization code', () async {
    when(
      () => auth.revokeTokenWithAuthorizationCode('fresh-synthetic-code'),
    ).thenAnswer((_) async {});
    await client.revoke('fresh-synthetic-code');
    verify(
      () => auth.revokeTokenWithAuthorizationCode('fresh-synthetic-code'),
    ).called(1);
  });
}
