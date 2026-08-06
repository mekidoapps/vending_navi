import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';

void main() {
  test('固定ジャンルIDをenumへ変換できる', () {
    expect(ProductGenre.tryFromId('green_tea'), ProductGenre.greenTea);
    expect(ProductGenre.tryFromId('energy_drink'), ProductGenre.energyDrink);
  });

  test('未知のジャンルIDはnullにして呼び出し側へ判断を委ねる', () {
    expect(ProductGenre.tryFromId('milk'), isNull);
  });

  test('MVPの固定ジャンルIDが重複しない', () {
    final ids = ProductGenre.values.map((genre) => genre.id).toList();

    expect(ids.toSet().length, ids.length);
    expect(ids, containsAll(<String>['tea', 'green_tea', 'other']));
  });
}
