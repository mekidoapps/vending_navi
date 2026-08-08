import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../product_master/domain/entities/product_genre.dart';

final genreSearchSelectionControllerProvider =
    NotifierProvider<GenreSearchSelectionController, ProductGenre?>(
      GenreSearchSelectionController.new,
      name: 'genreSearchSelectionControllerProvider',
    );

final class GenreSearchSelectionController extends Notifier<ProductGenre?> {
  @override
  ProductGenre? build() => null;

  void select(ProductGenre genre) {
    state = genre;
  }

  void clear() {
    state = null;
  }
}
