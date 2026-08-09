import 'package:flutter/services.dart';

import '../../../../core/errors/app_failure.dart';

abstract final class GoogleSignInFailureMapper {
  static bool isCancellationCode(String code) {
    return switch (code.trim().toLowerCase()) {
      'sign_in_canceled' ||
      'sign_in_cancelled' ||
      'canceled' ||
      'cancelled' => true,
      _ => false,
    };
  }

  static AppFailure fromPlatformException(PlatformException exception) {
    final code = exception.code.trim().toLowerCase();

    if (code.contains('network')) {
      return const NetworkFailure();
    }

    return FirebaseFailure(
      plugin: 'google_sign_in',
      sourceCode: exception.code,
    );
  }
}
