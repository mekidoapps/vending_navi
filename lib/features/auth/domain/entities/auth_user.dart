final class AuthUser {
  AuthUser({
    required String uid,
    required this.email,
    required this.displayName,
    required List<String> providerIds,
    required this.emailVerified,
  }) : uid = _validatedUid(uid),
       providerIds = List<String>.unmodifiable(
         providerIds
             .map((providerId) => providerId.trim())
             .where((providerId) => providerId.isNotEmpty)
             .toSet()
             .toList(growable: false)
           ..sort(),
       );

  final String uid;
  final String? email;
  final String? displayName;
  final List<String> providerIds;
  final bool emailVerified;

  bool hasProvider(String providerId) {
    final normalized = providerId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return providerIds.contains(normalized);
  }

  static String _validatedUid(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'uid', 'uid must not be empty');
    }
    return normalized;
  }
}
