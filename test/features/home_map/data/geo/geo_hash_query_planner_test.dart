import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/home_map/data/geo/geo_hash_query_planner.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';

void main() {
  test('狭いviewportから重複なしprefixを生成する', () {
    final bounds = MapViewportBounds(
      south: 35.67,
      west: 139.75,
      north: 35.69,
      east: 139.78,
    );

    final prefixes = GeoHashQueryPlanner.prefixesForBounds(bounds);

    expect(prefixes, isNotEmpty);
    expect(prefixes.length, lessThanOrEqualTo(9));
    expect(prefixes.any((prefix) => 'xn76ur'.startsWith(prefix)), isTrue);
  });

  test('日付変更線をまたいでもprefixを生成できる', () {
    final bounds = MapViewportBounds(
      south: -1,
      west: 179,
      north: 1,
      east: -179,
    );

    final prefixes = GeoHashQueryPlanner.prefixesForBounds(bounds);

    expect(prefixes, isNotEmpty);
  });
}
