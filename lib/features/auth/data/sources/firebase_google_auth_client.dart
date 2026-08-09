import 'package:firebase_auth/firebase_auth.dart';

import '../dto/auth_user_dto.dart';
import 'google_firebase_auth_client.dart';
import 'google_sign_in_client.dart';

final class FirebaseGoogleAuthClient implements GoogleFirebaseAuthClient {
  const FirebaseGoogleAuthClient(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<AuthUserDto> signInWithTokens(GoogleSignInTokens tokens) async {
    final credential = GoogleAuthProvider.credential(
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );

    final result = await _auth.signInWithCredential(credential);

    final user = result.user;
    if (user == null) {
      throw StateError(
        'Firebase Google authentication completed without a user.',
      );
    }

    return AuthUserDto.fromFirebase(user);
  }
}
