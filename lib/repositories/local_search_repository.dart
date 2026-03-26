import '../core/enums/app_enums.dart';
import '../core/utils/distance_util.dart';
import '../data/seed/machine_dummy_data.dart';
import '../data/seed/machine_item_dummy_data.dart';
import '../data/seed/product_master_data.dart';
import '../models/product.dart';
import '../models/vending_machine.dart';
import '../models/vending_machine_access.dart';
import 'search_repository.dart';

class LocalSearchRepository {
  Future<List<SearchResultItem>> search({
    required String keyword,
    ProductCategory? category,
    ItemTemperature? temperatureFilter,
    double? currentLatitude,
    double? currentLongitude,
    SearchSortType sortType = SearchSortType.nearest,
  }) async {
    final List<Product> matchedProducts = _filterProducts(
      keyword: keyword,
      category: category,
    );

    if (matchedProducts.isEmpty) {
      return <SearchResultItem>[];
    }

    final Set<String> matchedProductIds =
    matchedProducts.map((Product e) => e.id).toSet();

    final Map<String, Product> productMap = <String, Product>{
      for (final Product product in ProductMasterData.products) product.id: product,
    };

    final Map<String, VendingMachine> machineMap = <String, VendingMachine>{
      for (final VendingMachine machine in MachineDummyData.items) machine.id: machine,
    };

    final List<SearchResultItem> results = <SearchResultItem>[];

    for (final VendingMachineAccess access in MachineItemDummyData.items) {
      if (!matchedProductIds.contains(access.productId)) {
        continue;
      }

      if (temperatureFilter != null &&
          temperatureFilter != ItemTemperature.unknown &&
          access.temperature != temperatureFilter &&
          access.temperature != ItemTemperature.both) {
        continue;
      }

      final Product? product = productMap[access.productId];
      final VendingMachine? machine = machineMap[access.machineId];

      if (product == null || machine == null) {
        continue;
      }

      if (machine.status != MachineStatus.active) {
        continue;
      }

      double? distanceKm;
      if (currentLatitude != null && currentLongitude != null) {
        distanceKm = DistanceUtil.calculateDistanceKm(
          startLatitude: currentLatitude,
          startLongitude: currentLongitude,
          endLatitude: machine.latitude,
          endLongitude: machine.longitude,
        );
      }

      results.add(
        SearchResultItem(
          machineId: machine.id,
          productId: product.id,
          productName: access.productNameSnapshot.isNotEmpty
              ? access.productNameSnapshot
              : product.displayName,
          brandName: product.brandName,
          machineName: machine.name,
          placeNote: machine.placeNote,
          price: access.price,
          temperature: access.temperature,
          stockStatus: access.stockStatus,
          confidence: access.confidence,
          lastSeenAt: access.lastSeenAt,
          latitude: machine.latitude,
          longitude: machine.longitude,
          distanceKm: distanceKm,
        ),
      );
    }

    _sortResults(results, sortType, keyword);
    return results;
  }

  List<Product> _filterProducts({
    required String keyword,
    ProductCategory? category,
  }) {
    final String trimmed = keyword.trim();

    return ProductMasterData.products.where((Product product) {
      if (product.status != ProductStatus.active) {
        return false;
      }

      if (category != null && product.category != category) {
        return false;
      }

      if (trimmed.isEmpty) {
        return true;
      }

      return product.matchesKeyword(trimmed);
    }).toList();
  }

  void _sortResults(
      List<SearchResultItem> results,
      SearchSortType sortType,
      String keyword,
      ) {
    switch (sortType) {
      case SearchSortType.latest:
        results.sort((SearchResultItem a, SearchResultItem b) {
          final DateTime aDate =
              a.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime bDate =
              b.lastSeenAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        return;

      case SearchSortType.cheapest:
        results.sort((SearchResultItem a, SearchResultItem b) {
          final int aPrice = a.price ?? 999999;
          final int bPrice = b.price ?? 999999;
          if (aPrice != bPrice) {
            return aPrice.compareTo(bPrice);
          }
          final double aDistance = a.distanceKm ?? 999999;
          final double bDistance = b.distanceKm ?? 999999;
          return aDistance.compareTo(bDistance);
        });
        return;

      case SearchSortType.bestMatch:
        final String lowerKeyword = keyword.trim().toLowerCase();
        results.sort((SearchResultItem a, SearchResultItem b) {
          final int aScore = _matchScore(a, lowerKeyword);
          final int bScore = _matchScore(b, lowerKeyword);

          if (aScore != bScore) {
            return bScore.compareTo(aScore);
          }

          final double aDistance = a.distanceKm ?? 999999;
          final double bDistance = b.distanceKm ?? 999999;
          return aDistance.compareTo(bDistance);
        });
        return;

      case SearchSortType.nearest:
        results.sort((SearchResultItem a, SearchResultItem b) {
          final double aDistance = a.distanceKm ?? 999999;
          final double bDistance = b.distanceKm ?? 999999;
          return aDistance.compareTo(bDistance);
        });
        return;
    }
  }

  int _matchScore(SearchResultItem item, String keyword) {
    if (keyword.isEmpty) return 0;

    final String product = item.productName.toLowerCase();
    final String brand = item.brandName.toLowerCase();

    if (product == keyword) return 100;
    if (brand == keyword) return 90;
    if (product.startsWith(keyword)) return 80;
    if (brand.startsWith(keyword)) return 70;
    if (product.contains(keyword)) return 60;
    if (brand.contains(keyword)) return 50;
    return 0;
  }
}