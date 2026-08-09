import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/auth/data/dto/auth_user_dto.dart';
import 'package:vending_app/features/auth/data/mappers/auth_user_mapper.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';

void main() {
  test('Firebase境界DTOをDomain AuthUserへ変換する', () {
    final session = AuthUserMapper.toSession(
      AuthUserDto(
        uid: ' user_123 ',
        email: 'user@example.com',
        displayName: 'Test User',
        providerIds: const <String>['google.com', 'password', 'google.com'],
        emailVerified: true,
      ),
    );

    expect(session, isA<AuthenticatedAuthSession>());

    final user = session.userOrNull!;
    expect(user.uid, 'user_123');
    expect(user.email, 'user@example.com');
    expect(user.displayName, 'Test User');
    expect(user.providerIds, <String>['google.com', 'password']);
    expect(user.emailVerified, isTrue);
    expect(user.hasProvider('google.com'), isTrue);
  });

  test('null userはGuest sessionになる', () {
    final session = AuthUserMapper.toSession(null);

    expect(session, isA<GuestAuthSession>());
    expect(session.isAuthenticated, isFalse);
    expect(session.userOrNull, isNull);
  });
}
