import 'package:firebase_auth/firebase_auth.dart';

final class AuthUserDto {
  AuthUserDto({
    required String uid,
    required this.email,
    required this.displayName,
    required List<String> providerIds,
    required this.emailVerified,
  }) : uid = uid.trim(),
       providerIds = List<String>.unmodifiable(
         providerIds
             .map((providerId) => providerId.trim())
             .where((providerId) => providerId.isNotEmpty)
             .toSet()
             .toList(growable: false)
           ..sort(),
       );

  factory AuthUserDto.fromFirebase(User user) {
    return AuthUserDto(
      uid: user.uid,
      email: _normalizedOptional(user.email),
      displayName: _normalizedOptional(user.displayName),
      providerIds: user.providerData
          .map((provider) => provider.providerId)
          .toList(growable: false),
      emailVerified: user.emailVerified,
    );
  }

  final String uid;
  final String? email;
  final String? displayName;
  final List<String> providerIds;
  final bool emailVerified;

  static String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
