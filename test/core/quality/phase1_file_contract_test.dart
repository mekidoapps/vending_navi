import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 1の必須ファイルがリポジトリ内に存在する', () {
    const requiredPaths = <String>[
      'lib/app/bootstrap/app_bootstrap.dart',
      'lib/app/router/app_router.dart',
      'lib/app/theme/v2_theme.dart',
      'lib/core/errors/app_failure.dart',
      'lib/core/result/app_result.dart',
      'lib/core/logging/app_logger.dart',
      'lib/core/firebase/firebase_emulator_connector.dart',
      'lib/features/foundation/presentation/v2_foundation_screen.dart',
      'firebase.v2.json',
      'firebase/v2/firestore.rules',
      'firebase/v2/storage.rules',
      'functions/package.json',
    ];

    for (final path in requiredPaths) {
      expect(File(path).existsSync(), isTrue, reason: '$path is required');
    }
  });

  test('v2 Rulesはdeny-by-defaultで開始する', () {
    final firestoreRules = File(
      'firebase/v2/firestore.rules',
    ).readAsStringSync();
    final storageRules = File('firebase/v2/storage.rules').readAsStringSync();

    final denyAllPattern = RegExp(
      r'allow\s+read,\s*write:\s*if\s+false;',
      multiLine: true,
    );

    expect(firestoreRules, matches(denyAllPattern));
    expect(storageRules, matches(denyAllPattern));
  });
}
