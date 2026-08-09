import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../mappers/auth_user_mapper.dart';
import '../sources/auth_data_source.dart';

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._source);

  final AuthDataSource _source;

  @override
  AuthSession get currentSession {
    return AuthUserMapper.toSession(_source.currentUser);
  }

  @override
  Stream<AuthSession> watchSession() {
    return _source.authStateChanges().map(AuthUserMapper.toSession);
  }
}
