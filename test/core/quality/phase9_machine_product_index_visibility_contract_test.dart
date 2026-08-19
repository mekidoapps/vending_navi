import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('machine product search query includes public visibility filters', () {
    final source = File(
      'lib/features/product_search/data/sources/'
      'firestore_machine_product_index_source.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(".where('isActive', isEqualTo: true)"),
    );
    expect(
      source,
      contains(".where('machineStatus', isEqualTo: 'active')"),
    );
  });

  test('machine product index rules expose only public search entries', () {
    final rules = File(
      'firebase/v2/firestore.rules',
    ).readAsStringSync();

    expect(
      rules,
      contains('resource.data.isActive == true'),
    );
    expect(
      rules,
      contains("resource.data.machineStatus == 'active'"),
    );
  });

  test('machine product search composite index matches query contract', () {
    final raw = jsonDecode(
      File('firebase/v2/firestore.indexes.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final indexes = raw['indexes'] as List<dynamic>;

    final index = indexes
        .cast<Map<String, dynamic>>()
        .singleWhere(
          (item) =>
              item['collectionGroup'] == 'machine_product_index',
        );

    final fields = (index['fields'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((item) => item['fieldPath'])
        .toList(growable: false);

    expect(
      fields,
      <dynamic>[
        'productId',
        'isActive',
        'machineStatus',
        'geohash',
      ],
    );
  });
}
