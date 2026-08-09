import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_client.dart';

final class FlutterGoogleSignInClient implements GoogleSignInClient {
  const FlutterGoogleSignInClient(this._googleSignIn);

  final GoogleSignIn _googleSignIn;

  @override
  Future<GoogleSignInTokens?> signIn() async {
    final account = await _googleSignIn.signIn();

    if (account == null) {
      return null;
    }

    final authentication = await account.authentication;
    final tokens = GoogleSignInTokens(
      idToken: _normalize(authentication.idToken),
      accessToken: _normalize(authentication.accessToken),
    );

    if (!tokens.hasCredential) {
      throw StateError(
        'Google Sign-In completed without an authentication token.',
      );
    }

    return tokens;
  }

  String? _normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
