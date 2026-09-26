import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OSM lists are capped and all client writes are denied', () {
    final rules = File('firebase/v2/firestore.rules').readAsStringSync();
    expect(rules, contains('match /osm_vending_seed/{sourceId}'));
    expect(rules, contains('match /osm_vending_aggregate/{cellId}'));
    expect(rules, contains('request.query.limit <= 121'));
    expect(rules, contains('request.query.limit <= 81'));
    final sections = rules.split('match /osm_vending_');
    for (final section in sections.skip(1).take(2)) {
      expect(section, contains("resource.data.status == 'published'"));
      expect(section, contains('allow write: if false;'));
    }
  });

  test('only two OSM composite indexes are added', () {
    final config =
        jsonDecode(
              File('firebase/v2/firestore.indexes.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final indexes = (config['indexes'] as List).cast<Map<String, dynamic>>();
    final osm = indexes
        .where(
          (entry) => (entry['collectionGroup'] as String).startsWith('osm_'),
        )
        .toList();
    expect(osm, hasLength(2));
    expect(
      osm.map((entry) => entry['collectionGroup']),
      containsAll(['osm_vending_seed', 'osm_vending_aggregate']),
    );
  });
}
