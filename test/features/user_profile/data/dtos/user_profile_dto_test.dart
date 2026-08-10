import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/user_profile/data/dtos/user_profile_dto.dart';

void main() {
  test('appDisplayNameとlegacy displayNameを未知fieldと共存して読める', () {
    final dto = UserProfileDto.fromFirestore(
      documentId: 'user_1',
      data: <String, dynamic>{
        'appDisplayName': '  v2表示名  ',
        'displayName': '旧表示名',
        'favoriteDrinkNames': <String>['水'],
        'registeredMachineCount': 12,
      },
    );

    final profile = dto.toDomain();

    expect(profile.uid, 'user_1');
    expect(profile.appDisplayName, 'v2表示名');
    expect(profile.legacyDisplayName, '旧表示名');
    expect(profile.storedDisplayName, 'v2表示名');
  });

  test('appDisplayName欠損時はlegacy displayNameをfallbackにする', () {
    final dto = UserProfileDto.fromFirestore(
      documentId: 'user_2',
      data: <String, dynamic>{'displayName': 'legacy'},
    );

    expect(dto.toDomain().storedDisplayName, 'legacy');
  });
}
