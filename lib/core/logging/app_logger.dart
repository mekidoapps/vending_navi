import 'package:flutter/foundation.dart';

import '../errors/app_failure.dart';
import 'log_event.dart';

abstract interface class AppLogger {
  void record(LogEvent event);
}

final class DebugAppLogger implements AppLogger {
  const DebugAppLogger();

  @override
  void record(LogEvent event) {
    if (kDebugMode) {
      debugPrint(event.toSafeLine());
    }
  }
}

final class NoopAppLogger implements AppLogger {
  const NoopAppLogger();

  @override
  void record(LogEvent event) {}
}

extension AppLoggerEvents on AppLogger {
  void success({
    required String operation,
    required Duration duration,
    String? requestId,
    String? appVersion,
  }) {
    record(
      LogEvent.success(
        operation: operation,
        duration: duration,
        requestId: requestId,
        appVersion: appVersion,
      ),
    );
  }

  void failure({
    required String operation,
    required AppFailure failure,
    required Duration duration,
    String? requestId,
    String? appVersion,
  }) {
    record(
      LogEvent.failure(
        operation: operation,
        errorCode: failure.code,
        duration: duration,
        requestId: requestId,
        appVersion: appVersion,
      ),
    );
  }
}
