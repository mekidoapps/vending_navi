import '../dtos/user_profile_dto.dart';

abstract interface class UserProfileDataSource {
  Future<UserProfileDto> getOrCreateProfile({required String uid});

  Future<UserProfileDto> saveDisplayName({
    required String uid,
    required String? displayName,
  });
}
