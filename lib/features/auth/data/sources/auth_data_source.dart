import '../dto/auth_user_dto.dart';

abstract interface class AuthDataSource {
  AuthUserDto? get currentUser;

  Stream<AuthUserDto?> authStateChanges();
}
