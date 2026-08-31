import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> loadConfig(String path) {
    return jsonDecode(File(path).readAsStringSync())
        as Map<String, dynamic>;
  }

  test('canonical Firebase config owns production and emulator resources', () {
    final config = loadConfig('firebase.json');

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

    expect(config.containsKey('emulators'), isTrue);
  });

  test('Firebase default project is fixed and obsolete configs are absent', () {
    final projectConfig = loadConfig('.firebaserc');
    final projects = projectConfig['projects'] as Map<String, dynamic>;

    expect(projects['default'], 'vendingnavi');
    expect(File('firebase.v2.json').existsSync(), isFalse);
    expect(File('firebase.v2.production.json').existsSync(), isFalse);
    expect(File('firestore.rules').existsSync(), isFalse);
    expect(File('firebase/v2/storage.emulator.rules').existsSync(), isFalse);
  });
}
