import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/domain/entities/product_genre.dart';
import 'package:vending_app/features/product_search/application/genre_search_selection_controller.dart';

void main() {
  test('ジャンルを選択して解除できる', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(
      genreSearchSelectionControllerProvider.notifier,
    );

    controller.select(ProductGenre.coffee);

    expect(
      container.read(genreSearchSelectionControllerProvider),
      ProductGenre.coffee,
    );

    controller.clear();

    expect(container.read(genreSearchSelectionControllerProvider), isNull);
  });
}
