import '../dto/auth_user_dto.dart';
import 'google_sign_in_client.dart';

abstract interface class GoogleFirebaseAuthClient {
  Future<AuthUserDto> signInWithTokens(GoogleSignInTokens tokens);
}
