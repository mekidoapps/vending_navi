import 'package:firebase_auth/firebase_auth.dart';

import '../dto/auth_user_dto.dart';
import 'google_firebase_auth_client.dart';
import 'google_sign_in_client.dart';

final class FirebaseGoogleAuthClient implements GoogleFirebaseAuthClient {
  const FirebaseGoogleAuthClient(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<AuthUserDto> signInWithTokens(GoogleSignInTokens tokens) async {
    final result = await _auth.signInWithCredential(_credential(tokens));

    final user = result.user;
    if (user == null) {
      throw StateError(
        'Firebase Google authentication completed without a user.',
      );
    }

    return AuthUserDto.fromFirebase(user);
  }

  @override
  Future<void> reauthenticateWithTokens(GoogleSignInTokens tokens) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    await user.reauthenticateWithCredential(_credential(tokens));
    await user.getIdToken(true);
  }

  OAuthCredential _credential(GoogleSignInTokens tokens) {
    return GoogleAuthProvider.credential(
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
  }
}
