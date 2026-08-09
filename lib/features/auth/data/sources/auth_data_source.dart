import '../dto/auth_user_dto.dart';

abstract interface class AuthDataSource {
  AuthUserDto? get currentUser;

  Stream<AuthUserDto?> authStateChanges();

  Future<AuthUserDto> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUserDto> registerWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> sendPasswordResetEmail({required String email});
}
