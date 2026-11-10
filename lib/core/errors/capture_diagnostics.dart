import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_failure.dart';

/// Capture-only closed vocabulary. Never accepts messages, IDs or token values.
abstract final class CaptureDiagnostics {
  static bool get enabled => kDebugMode &&
      const bool.fromEnvironment('CAPTURE_DIAGNOSTICS', defaultValue: false);
  static const events = {'appcheck', 'viewport_v2', 'viewport_legacy', 'machine_detail', 'viewport_state'};
  static const results = {'started', 'accepted', 'ready', 'empty', 'loading',
    'permission-denied', 'failed-precondition', 'unavailable', 'deadline-exceeded',
    'resource-exhausted', 'unauthenticated', 'invalid-configuration',
    'server-unreachable', 'code-keychain', 'code-unsupported', 'network',
    'authentication', 'permission', 'validation', 'rate-limit', 'not-found',
    'unknown', 'other'};
  static void emit(String event, String result) {
    if (!enabled || !events.contains(event) || !results.contains(result)) return;
    debugPrintSynchronously('[CAPTURE_DIAGNOSTIC] ${jsonEncode({'event': event, 'result': result})}');
  }
  static String classify(Object error) {
    if (error is FirebaseException) return results.contains(error.code) ? error.code : 'other';
    if (error is PlatformException) return results.contains(error.code) ? error.code : 'other';
    if (error is NetworkFailure) return 'network';
    if (error is AuthenticationFailure) return 'authentication';
    if (error is PermissionFailure) return 'permission';
    if (error is ValidationFailure) return 'validation';
    if (error is RateLimitFailure) return 'rate-limit';
    if (error is NotFoundFailure) return 'not-found';
    if (error is FirebaseFailure) return results.contains(error.sourceCode) ? error.sourceCode : 'other';
    return 'unknown';
  }
  static Future<T> trace<T>(String event, Future<T> Function() action) async {
    emit(event, 'started');
    try {
      final value = await action();
      emit(event, 'ready');
      return value;
    } on Object catch (error) {
      emit(event, classify(error));
      rethrow;
    }
  }
}
