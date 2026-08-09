import 'package:firebase_auth/firebase_auth.dart';

import '../dto/auth_user_dto.dart';
import 'auth_data_source.dart';

final class FirebaseAuthDataSource implements AuthDataSource {
  const FirebaseAuthDataSource(this._auth);

  final FirebaseAuth _auth;

  @override
  AuthUserDto? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AuthUserDto.fromFirebase(user);
  }

  @override
  Stream<AuthUserDto?> authStateChanges() {
    return _auth.authStateChanges().map(
      (user) => user == null ? null : AuthUserDto.fromFirebase(user),
    );
  }
}
