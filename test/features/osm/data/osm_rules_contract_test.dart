import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('read path, rules and index collection names remain aligned', () {
    final source = File('lib/features/osm/data/osm_map_repository.dart')
        .readAsStringSync();
    final rules = File('firebase/v2/firestore.rules').readAsStringSync();
    final indexes = File('firebase/v2/firestore.indexes.json').readAsStringSync();
    for (final collection in ['osm_vending_seed', 'osm_vending_aggregate']) {
      expect(source, contains(".collection('$collection')"));
      expect(rules, contains('match /$collection/'));
      expect(indexes, contains('"collectionGroup": "$collection"'));
    }
    expect(source, isNot(contains('osm_vending_cells')));
    expect(rules, isNot(contains('osm_vending_cells')));
    expect(indexes, isNot(contains('osm_vending_cells')));
  });

  test('OSM lists are capped and all client writes are denied', () {
    final rules = File('firebase/v2/firestore.rules').readAsStringSync();
    expect(rules, contains('match /osm_vending_seed/{sourceId}'));
    expect(rules, contains('match /osm_vending_aggregate/{cellId}'));
    expect(rules, contains('match /osm_import_runs/{runId}'));
    expect(rules, contains('allow read, write: if false;'));
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
