final class UserProfile {
  UserProfile({
    required String uid,
    String? appDisplayName,
    String? legacyDisplayName,
  }) : uid = _validatedUid(uid),
       appDisplayName = _normalizedOptional(appDisplayName),
       legacyDisplayName = _normalizedOptional(legacyDisplayName);

  final String uid;

  /// v1 MyPageの明示的な表示名フィールド。
  final String? appDisplayName;

  /// v1の各登録処理でも利用されている互換表示名フィールド。
  final String? legacyDisplayName;

  String? get storedDisplayName => appDisplayName ?? legacyDisplayName;

  static String _validatedUid(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'uid', 'uid must not be empty');
    }
    return normalized;
  }

  static String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
