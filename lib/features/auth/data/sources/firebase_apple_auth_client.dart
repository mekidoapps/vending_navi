import 'package:firebase_auth/firebase_auth.dart';

import 'apple_auth_client.dart';

final class FirebaseAppleAuthClient implements AppleAuthClient {
  const FirebaseAppleAuthClient(this._auth);
  final FirebaseAuth _auth;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  bool get hasAppleProvider =>
      _auth.currentUser?.providerData.any(
        (provider) => provider.providerId == 'apple.com',
      ) ??
      false;

  AppleAuthProvider _provider() => AppleAuthProvider()
    ..addScope('email')
    ..addScope('name');

  @override
  Future<void> signIn() async {
    // Firebase's native provider flow handles the nonce and Apple authorization.
    // Never link or merge a pre-existing account automatically.
    final result = await _auth.signInWithProvider(_provider());
    if (result.user == null || currentUid != result.user?.uid) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
  }

  @override
  Future<String?> reauthenticate() async {
    final user = _auth.currentUser;
    if (user == null || !hasAppleProvider) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    final result = await user.reauthenticateWithProvider(_provider());
    if (result.user?.uid != user.uid || currentUid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
    await user.getIdToken(true);
    return result.additionalUserInfo?.authorizationCode;
  }

  @override
  Future<void> revoke(String authorizationCode) =>
      _auth.revokeTokenWithAuthorizationCode(authorizationCode);
}
