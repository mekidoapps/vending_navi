import 'package:firebase_core/firebase_core.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/result/app_result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../mappers/user_profile_failure_mapper.dart';
import '../sources/user_profile_data_source.dart';

final class UserProfileRepositoryImpl implements UserProfileRepository {
  const UserProfileRepositoryImpl(this._source);

  final UserProfileDataSource _source;

  @override
  Future<AppResult<UserProfile>> getOrCreateProfile({
    required String uid,
  }) async {
    try {
      final dto = await _source.getOrCreateProfile(uid: uid);
      return AppResult<UserProfile>.success(dto.toDomain());
    } on FirebaseException catch (error) {
      return AppResult<UserProfile>.failure(
        UserProfileFailureMapper.fromFirebaseException(error),
      );
    } on ArgumentError {
      return const AppResult<UserProfile>.failure(
        ValidationFailure(field: 'uid'),
      );
    } catch (_) {
      return const AppResult<UserProfile>.failure(UnknownFailure());
    }
  }

  @override
  Future<AppResult<UserProfile>> saveDisplayName({
    required String uid,
    required String? displayName,
  }) async {
    try {
      final dto = await _source.saveDisplayName(
        uid: uid,
        displayName: displayName,
      );
      return AppResult<UserProfile>.success(dto.toDomain());
    } on FirebaseException catch (error) {
      return AppResult<UserProfile>.failure(
        UserProfileFailureMapper.fromFirebaseException(error),
      );
    } on ArgumentError {
      return const AppResult<UserProfile>.failure(ValidationFailure());
    } catch (_) {
      return const AppResult<UserProfile>.failure(UnknownFailure());
    }
  }
}
