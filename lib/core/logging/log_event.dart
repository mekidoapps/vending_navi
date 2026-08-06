enum LogOutcome { success, failure }

final class LogEvent {
  factory LogEvent.success({
    required String operation,
    required Duration duration,
    String? requestId,
    String? appVersion,
  }) {
    return LogEvent._(
      operation: operation,
      outcome: LogOutcome.success,
      duration: duration,
      requestId: requestId,
      appVersion: appVersion,
    );
  }

  factory LogEvent.failure({
    required String operation,
    required String errorCode,
    required Duration duration,
    String? requestId,
    String? appVersion,
  }) {
    return LogEvent._(
      operation: operation,
      outcome: LogOutcome.failure,
      errorCode: errorCode,
      duration: duration,
      requestId: requestId,
      appVersion: appVersion,
    );
  }

  LogEvent._({
    required String operation,
    required this.outcome,
    required Duration duration,
    String? errorCode,
    String? requestId,
    String? appVersion,
  }) : operation = _safeToken(operation, fallback: 'unknown_operation'),
       errorCode = _nullableSafeToken(errorCode),
       durationMilliseconds = duration.inMilliseconds < 0
           ? 0
           : duration.inMilliseconds,
       requestId = _nullableSafeToken(requestId),
       appVersion = _nullableSafeToken(appVersion);

  /// Fixed operation identifier such as `machine.search`.
  final String operation;
  final LogOutcome outcome;
  final String? errorCode;
  final int durationMilliseconds;
  final String? requestId;
  final String? appVersion;

  /// Returns only metadata approved by the v2 logging policy.
  ///
  /// Never add email addresses, photo URLs, image data, exact coordinates,
  /// feedback text, or raw AI responses to this map.
  Map<String, Object> toSafeMap() {
    return <String, Object>{
      'operation': operation,
      'outcome': outcome.name,
      'durationMs': durationMilliseconds,
      if (errorCode != null) 'errorCode': errorCode!,
      if (requestId != null) 'requestId': requestId!,
      if (appVersion != null) 'appVersion': appVersion!,
    };
  }

  String toSafeLine() {
    final fields = toSafeMap().entries
        .map((MapEntry<String, Object> entry) => '${entry.key}=${entry.value}')
        .join(' ');
    return '[VendingNavi] $fields';
  }
}

String? _nullableSafeToken(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return _safeToken(value, fallback: 'unknown');
}

String _safeToken(String value, {required String fallback}) {
  final normalized = value.trim().replaceAll(
    RegExp(r'[^a-zA-Z0-9._:+-]+'),
    '_',
  );
  if (normalized.isEmpty) {
    return fallback;
  }
  return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
}
