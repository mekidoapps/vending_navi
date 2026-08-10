import '../../domain/entities/user_profile.dart';

final class UserProfileDto {
  const UserProfileDto({
    required this.documentId,
    required this.appDisplayName,
    required this.legacyDisplayName,
  });

  factory UserProfileDto.fromFirestore({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return UserProfileDto(
      documentId: documentId,
      appDisplayName: _optionalString(data['appDisplayName']),
      legacyDisplayName: _optionalString(data['displayName']),
    );
  }

  final String documentId;
  final String? appDisplayName;
  final String? legacyDisplayName;

  UserProfile toDomain() {
    return UserProfile(
      uid: documentId,
      appDisplayName: appDisplayName,
      legacyDisplayName: legacyDisplayName,
    );
  }

  static String? _optionalString(dynamic value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
