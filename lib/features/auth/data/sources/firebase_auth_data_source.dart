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

  @override
  Future<AuthUserDto> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return _requiredUser(credential);
  }

  @override
  Future<AuthUserDto> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    return _requiredUser(credential);
  }

  @override
  Future<void> reauthenticateWithEmailPassword({
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  AuthUserDto _requiredUser(UserCredential credential) {
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase Auth completed without a user.');
    }

    return AuthUserDto.fromFirebase(user);
  }
}
