import '../../product_master/domain/entities/product.dart';
import '../../product_master/domain/entities/product_genre.dart';
import 'models/vending_machine_detail_data.dart';

abstract final class VendingMachineDetailSearchPriority {
  static List<VendingMachineProductDetailItem> orderedProducts({
    required List<VendingMachineProductDetailItem> products,
    required Product? selectedProduct,
    required ProductGenre? selectedGenre,
  }) {
    final result = List<VendingMachineProductDetailItem>.of(products);

    result.sort((left, right) {
      final searchOrder =
          _searchOrder(
            left,
            selectedProduct: selectedProduct,
            selectedGenre: selectedGenre,
          ).compareTo(
            _searchOrder(
              right,
              selectedProduct: selectedProduct,
              selectedGenre: selectedGenre,
            ),
          );

      if (searchOrder != 0) {
        return searchOrder;
      }

      final evidenceOrder = _evidenceOrder(
        left,
      ).compareTo(_evidenceOrder(right));
      if (evidenceOrder != 0) {
        return evidenceOrder;
      }

      return left.productName.compareTo(right.productName);
    });

    return List<VendingMachineProductDetailItem>.unmodifiable(result);
  }

  static bool isSearchMatch({
    required VendingMachineProductDetailItem item,
    required Product? selectedProduct,
    required ProductGenre? selectedGenre,
  }) {
    final product = selectedProduct;
    if (product != null) {
      return item.productId == product.id;
    }

    final genre = selectedGenre;
    if (genre != null) {
      return item.genres.contains(genre);
    }

    return false;
  }

  static String? searchLabel({
    required Product? selectedProduct,
    required ProductGenre? selectedGenre,
  }) {
    final product = selectedProduct;
    if (product != null) {
      return product.name;
    }

    final genre = selectedGenre;
    if (genre != null) {
      return genre.label;
    }

    return null;
  }

  static int _searchOrder(
    VendingMachineProductDetailItem item, {
    required Product? selectedProduct,
    required ProductGenre? selectedGenre,
  }) {
    return isSearchMatch(
          item: item,
          selectedProduct: selectedProduct,
          selectedGenre: selectedGenre,
        )
        ? 0
        : 1;
  }

  static int _evidenceOrder(VendingMachineProductDetailItem item) {
    if (item.isConfirmed) {
      return 0;
    }
    if (item.isInferred) {
      return 1;
    }
    return 2;
  }
}
