import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/logging/app_logger.dart';
import 'package:vending_app/core/logging/log_event.dart';

void main() {
  test('成功ログには許可された固定メタデータだけを含める', () {
    final event = LogEvent.success(
      operation: 'machine.search',
      duration: const Duration(milliseconds: 125),
      requestId: 'request-123',
      appVersion: '2.0.0+1',
    );

    expect(event.toSafeMap(), <String, Object>{
      'operation': 'machine.search',
      'outcome': 'success',
      'durationMs': 125,
      'requestId': 'request-123',
      'appVersion': '2.0.0+1',
    });
  });

  test('失敗ログは生の例外ではなくAppFailureのコードを記録する', () {
    final logger = _MemoryLogger();

    logger.failure(
      operation: 'machine.register',
      failure: const PermissionFailure(),
      duration: const Duration(milliseconds: 80),
      requestId: 'request-456',
    );

    expect(logger.events, hasLength(1));
    expect(logger.events.single.errorCode, 'permission.denied');
    expect(logger.events.single.outcome, LogOutcome.failure);
    expect(
      logger.events.single.toSafeMap().keys,
      containsAll(<String>[
        'operation',
        'outcome',
        'durationMs',
        'errorCode',
        'requestId',
      ]),
    );
  });

  test('ログ用トークンから空白や記号を除去する', () {
    final event = LogEvent.failure(
      operation: 'machine search',
      errorCode: 'firebase / unavailable',
      duration: const Duration(milliseconds: -1),
    );

    expect(event.operation, 'machine_search');
    expect(event.errorCode, 'firebase_unavailable');
    expect(event.durationMilliseconds, 0);
  });
}

final class _MemoryLogger implements AppLogger {
  final List<LogEvent> events = <LogEvent>[];

  @override
  void record(LogEvent event) {
    events.add(event);
  }
}
