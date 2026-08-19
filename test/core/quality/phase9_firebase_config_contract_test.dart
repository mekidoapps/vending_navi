import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> loadConfig(String path) {
    return jsonDecode(File(path).readAsStringSync())
        as Map<String, dynamic>;
  }

  test('v2 emulator config uses emulator-only Storage rules', () {
    final config = loadConfig('firebase.v2.json');

    final firestore = config['firestore'] as Map<String, dynamic>;
    final storage = config['storage'] as Map<String, dynamic>;

    expect(
      firestore['rules'],
      'firebase/v2/firestore.rules',
    );
    expect(
      storage['rules'],
      'firebase/v2/storage.emulator.rules',
    );
    expect(config.containsKey('emulators'), isTrue);
  });

  test('v2 production config uses production Storage rules', () {
    final config = loadConfig('firebase.v2.production.json');

    final firestore = config['firestore'] as Map<String, dynamic>;
    final storage = config['storage'] as Map<String, dynamic>;
    final functions = config['functions'] as List<dynamic>;
    final functionConfig = functions.single as Map<String, dynamic>;

    expect(
      firestore['rules'],
      'firebase/v2/firestore.rules',
    );
    expect(
      firestore['indexes'],
      'firebase/v2/firestore.indexes.json',
    );
    expect(
      storage['rules'],
      'firebase/v2/storage.rules',
    );
    expect(functionConfig['source'], 'functions');
    expect(functionConfig['codebase'], 'v2');

    // A production deployment config must never contain local Emulator
    // settings.
    expect(config.containsKey('emulators'), isFalse);
  });
}
