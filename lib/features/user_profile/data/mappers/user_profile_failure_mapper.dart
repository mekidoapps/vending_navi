import 'package:firebase_core/firebase_core.dart';

import '../../../../core/errors/app_failure.dart';

abstract final class UserProfileFailureMapper {
  static AppFailure fromFirebaseException(FirebaseException error) {
    final code = error.code.trim().toLowerCase();

    return switch (code) {
      'permission-denied' => const PermissionFailure(),
      'unauthenticated' => const AuthenticationFailure(),
      'unavailable' || 'deadline-exceeded' => const NetworkFailure(),
      'resource-exhausted' => const RateLimitFailure(),
      'not-found' => const NotFoundFailure(),
      'invalid-argument' => const ValidationFailure(),
      _ => FirebaseFailure(plugin: error.plugin, sourceCode: code),
    };
  }
}
