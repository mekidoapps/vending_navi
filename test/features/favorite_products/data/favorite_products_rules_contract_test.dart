import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v2 rulesはfavorite_productsを本人専用にする', () {
    final rules = File('firebase/v2/firestore.rules').readAsStringSync();

    expect(rules, contains('match /favorite_products/{productId}'));
    expect(rules, contains('request.auth.uid == uid'));
    expect(rules, contains('request.resource.data.productId == productId'));
    expect(rules, contains("'productId'"));
    expect(rules, contains("'sortOrder'"));
    expect(rules, contains("'createdAt'"));
    expect(rules, contains("match /migration_state/{migrationId}"));
  });

  test('production root rulesはP5-07 artifactで直接変更しない', () {
    expect(File('firestore.rules').existsSync(), isTrue);
  });
}
