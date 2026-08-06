import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

import 'app_failure.dart';

abstract final class FailureMapper {
  static AppFailure map(Object error) {
    if (error is AppFailure) {
      return error;
    }

    if (error is TimeoutException) {
      return const NetworkFailure();
    }

    if (error is FirebaseException) {
      return _fromCode(code: error.code, plugin: error.plugin);
    }

    if (error is PlatformException) {
      return _fromCode(code: error.code, plugin: 'platform');
    }

    if (error is FormatException || error is ArgumentError) {
      return const ValidationFailure();
    }

    return const UnknownFailure();
  }

  static AppFailure _fromCode({required String code, required String plugin}) {
    final normalizedCode = code.trim().toLowerCase().replaceAll('_', '-');

    if (_networkCodes.contains(normalizedCode)) {
      return const NetworkFailure();
    }
    if (_authenticationCodes.contains(normalizedCode)) {
      return const AuthenticationFailure();
    }
    if (_permissionCodes.contains(normalizedCode)) {
      return const PermissionFailure();
    }
    if (_validationCodes.contains(normalizedCode)) {
      return const ValidationFailure();
    }
    if (_rateLimitCodes.contains(normalizedCode)) {
      return const RateLimitFailure();
    }
    if (_notFoundCodes.contains(normalizedCode)) {
      return const NotFoundFailure();
    }

    return FirebaseFailure(plugin: plugin, sourceCode: normalizedCode);
  }

  static const Set<String> _networkCodes = <String>{
    'aborted',
    'deadline-exceeded',
    'network-error',
    'network-request-failed',
    'timeout',
    'unavailable',
  };

  static const Set<String> _authenticationCodes = <String>{
    'invalid-credential',
    'requires-recent-login',
    'unauthenticated',
    'user-disabled',
    'user-not-found',
    'wrong-password',
  };

  static const Set<String> _permissionCodes = <String>{
    'operation-not-allowed',
    'permission-denied',
    'unauthorized',
  };

  static const Set<String> _validationCodes = <String>{
    'invalid-argument',
    'invalid-email',
    'out-of-range',
    'weak-password',
  };

  static const Set<String> _rateLimitCodes = <String>{
    'quota-exceeded',
    'resource-exhausted',
    'too-many-requests',
  };

  static const Set<String> _notFoundCodes = <String>{
    'not-found',
    'object-not-found',
  };
}
