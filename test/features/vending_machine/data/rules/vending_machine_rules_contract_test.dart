import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P3-02 Rulesは自販機rootとproductsだけreadを公開する', () {
    final rules = File('firebase/v2/firestore.rules').readAsStringSync();

    expect(rules, contains('match /vending_machines/{machineId}'));
    expect(rules, contains('match /products/{productId}'));
    expect(rules, contains('allow read: if true;'));
    expect(rules, contains('allow write: if false;'));
    expect(rules, contains('match /{document=**}'));
    expect(rules, isNot(contains('match /revisions/{revisionId}')));
    expect(rules, isNot(contains('match /photos/{photoId}')));
  });
}
