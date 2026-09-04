import '../../../core/errors/app_failure.dart';

/// Controls the optional, privacy-safe authentication diagnostic shown on the
/// email authentication screen.
final class AuthDiagnostics {
  const AuthDiagnostics({this.enabled = _enabledByEnvironment});

  static const bool _enabledByEnvironment = bool.fromEnvironment(
    'AUTH_DIAGNOSTICS',
    defaultValue: false,
  );

  final bool enabled;

  /// Returns only the normalized application failure code.
  ///
  /// Exception messages and user input must never be returned here.
  String? codeForDisplay(AppFailure failure) {
    return enabled ? failure.code : null;
  }
}
