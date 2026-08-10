import '../../../../core/result/app_result.dart';
import '../entities/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<AppResult<UserProfile>> getOrCreateProfile({required String uid});

  Future<AppResult<UserProfile>> saveDisplayName({
    required String uid,
    required String? displayName,
  });
}
