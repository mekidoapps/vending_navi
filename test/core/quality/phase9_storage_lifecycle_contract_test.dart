import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('temporary photo lifecycle deletes only machine_uploads after one day', () {
    final raw = jsonDecode(
      File('firebase/v2/storage.lifecycle.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final rules = raw['rule'] as List<dynamic>;

    expect(rules, hasLength(1));

    final rule = rules.single as Map<String, dynamic>;
    final action = rule['action'] as Map<String, dynamic>;
    final condition = rule['condition'] as Map<String, dynamic>;

    expect(action['type'], 'Delete');
    expect(condition['age'], 1);
    expect(
      condition['matchesPrefix'],
      <dynamic>['machine_uploads/'],
    );
  });
}
