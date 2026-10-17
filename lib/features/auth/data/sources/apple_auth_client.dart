abstract interface class AppleAuthClient {
  String? get currentUid;
  bool get hasAppleProvider;
  Future<void> signIn();
  Future<String?> reauthenticate();
  Future<void> revoke(String authorizationCode);
}
