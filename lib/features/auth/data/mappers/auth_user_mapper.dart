import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';
import '../dto/auth_user_dto.dart';

abstract final class AuthUserMapper {
  static AuthUser toDomain(AuthUserDto dto) {
    return AuthUser(
      uid: dto.uid,
      email: dto.email,
      displayName: dto.displayName,
      providerIds: dto.providerIds,
      emailVerified: dto.emailVerified,
    );
  }

  static AuthSession toSession(AuthUserDto? dto) {
    if (dto == null) {
      return const GuestAuthSession();
    }

    return AuthenticatedAuthSession(toDomain(dto));
  }
}
