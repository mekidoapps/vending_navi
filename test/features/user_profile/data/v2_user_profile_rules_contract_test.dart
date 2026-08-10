import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v2 users Rulesは本人readと表示名限定writeだけを許可する', () {
    final rules = File('firebase/v2/firestore.rules').readAsStringSync();

    expect(rules, contains('match /users/{uid}'));
    expect(rules, contains('request.auth.uid == uid'));
    expect(rules, contains("'appDisplayName'"));
    expect(rules, contains("'displayName'"));
    expect(rules, contains('affectedKeys().hasOnly'));
    expect(rules, contains('allow delete: if false'));
  });
}
