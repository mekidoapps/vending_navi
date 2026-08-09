final class GoogleSignInTokens {
  const GoogleSignInTokens({required this.idToken, required this.accessToken});

  final String? idToken;
  final String? accessToken;

  bool get hasCredential {
    return _hasValue(idToken) || _hasValue(accessToken);
  }

  static bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

abstract interface class GoogleSignInClient {
  /// Returns null when the account chooser is closed/cancelled.
  Future<GoogleSignInTokens?> signIn();
}
