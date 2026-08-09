import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/google_auth_repository_impl.dart';
import '../../data/sources/firebase_google_auth_client.dart';
import '../../data/sources/flutter_google_sign_in_client.dart';
import '../../data/sources/google_firebase_auth_client.dart';
import '../../data/sources/google_sign_in_client.dart';
import '../../domain/repositories/google_auth_repository.dart';

final googleSignInClientProvider = Provider<GoogleSignInClient>(
  (ref) => FlutterGoogleSignInClient(GoogleSignIn()),
  name: 'googleSignInClientProvider',
);

final googleFirebaseAuthClientProvider = Provider<GoogleFirebaseAuthClient>(
  (ref) => FirebaseGoogleAuthClient(ref.watch(firebaseAuthProvider)),
  name: 'googleFirebaseAuthClientProvider',
);

final googleAuthRepositoryProvider = Provider<GoogleAuthRepository>(
  (ref) => GoogleAuthRepositoryImpl(
    googleSignInClient: ref.watch(googleSignInClientProvider),
    firebaseAuthClient: ref.watch(googleFirebaseAuthClientProvider),
  ),
  name: 'googleAuthRepositoryProvider',
);
