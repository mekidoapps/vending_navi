import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/repositories/apple_auth_repository_impl.dart';
import '../../data/sources/firebase_apple_auth_client.dart';
import '../../domain/repositories/apple_auth_repository.dart';

final appleSignInAvailableProvider = Provider<bool>(
  (_) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
);

final appleAuthRepositoryProvider = Provider<AppleAuthRepository>(
  (ref) => AppleAuthRepositoryImpl(
    FirebaseAppleAuthClient(ref.watch(firebaseAuthProvider)),
  ),
);
