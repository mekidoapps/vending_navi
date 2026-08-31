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
      '.firebaserc',
      'firebase.json',
      'firebase/v2/firestore.rules',
      'firebase/v2/storage.rules',
      'functions/package.json',
    ];

    for (final path in requiredPaths) {
      expect(File(path).existsSync(), isTrue, reason: '$path is required');
    }
  });

  test('旧Firebase deploy設定はリポジトリに存在しない', () {
    const obsoletePaths = <String>[
      'firebase.v2.json',
      'firebase.v2.production.json',
      'firestore.rules',
      'firebase/v2/storage.emulator.rules',
    ];

    for (final path in obsoletePaths) {
      expect(File(path).existsSync(), isFalse, reason: '$path is obsolete');
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
