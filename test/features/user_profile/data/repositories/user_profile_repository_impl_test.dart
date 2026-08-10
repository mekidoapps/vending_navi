import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/user_profile/data/dtos/user_profile_dto.dart';
import 'package:vending_app/features/user_profile/data/repositories/user_profile_repository_impl.dart';
import 'package:vending_app/features/user_profile/data/sources/user_profile_data_source.dart';

void main() {
  test('existing legacy profileをDomainへ変換する', () async {
    final repository = UserProfileRepositoryImpl(
      _FakeUserProfileDataSource(
        profile: const UserProfileDto(
          documentId: 'user_1',
          appDisplayName: null,
          legacyDisplayName: 'legacy name',
        ),
      ),
    );

    final result = await repository.getOrCreateProfile(uid: 'user_1');

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull?.storedDisplayName, 'legacy name');
  });

  test('permission-deniedを安全なPermissionFailureへ変換する', () async {
    final repository = UserProfileRepositoryImpl(
      _FakeUserProfileDataSource(
        profile: const UserProfileDto(
          documentId: 'user_1',
          appDisplayName: null,
          legacyDisplayName: null,
        ),
        error: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      ),
    );

    final result = await repository.getOrCreateProfile(uid: 'user_1');

    expect(result.failureOrNull, isA<PermissionFailure>());
  });

  test('表示名save結果をDomainへ返す', () async {
    final source = _FakeUserProfileDataSource(
      profile: const UserProfileDto(
        documentId: 'user_1',
        appDisplayName: null,
        legacyDisplayName: null,
      ),
    );
    final repository = UserProfileRepositoryImpl(source);

    final result = await repository.saveDisplayName(
      uid: 'user_1',
      displayName: 'mekido',
    );

    expect(result.isSuccess, isTrue);
    expect(result.valueOrNull?.storedDisplayName, 'mekido');
    expect(source.lastDisplayName, 'mekido');
  });
}

final class _FakeUserProfileDataSource implements UserProfileDataSource {
  _FakeUserProfileDataSource({required this.profile, this.error});

  final UserProfileDto profile;
  final FirebaseException? error;
  String? lastDisplayName;

  @override
  Future<UserProfileDto> getOrCreateProfile({required String uid}) async {
    if (error != null) {
      throw error!;
    }
    return profile;
  }

  @override
  Future<UserProfileDto> saveDisplayName({
    required String uid,
    required String? displayName,
  }) async {
    if (error != null) {
      throw error!;
    }

    lastDisplayName = displayName;
    return UserProfileDto(
      documentId: uid,
      appDisplayName: displayName,
      legacyDisplayName: displayName,
    );
  }
}
