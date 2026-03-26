import '../core/enums/app_enums.dart';
import '../core/utils/distance_util.dart';
import '../models/product.dart';
import '../models/vending_machine.dart';
import '../models/vending_machine_access.dart';
import 'machine_repository.dart';
import 'product_repository.dart';

class SearchResultItem {
  final String machineId;
  final String productId;
  final String productName;
  final String brandName;
  final String machineName;
  final String? placeNote;
  final int? price;
  final ItemTemperature temperature;
  final StockStatus stockStatus;
  final ConfidenceLevel confidence;
  final DateTime? lastSeenAt;
  final double latitude;
  final double longitude;
  final double? distanceKm;

  const SearchResultItem({
    required this.machineId,
    required this.productId,
    required this.productName,
    required this.brandName,
    required this.machineName,
    this.placeNote,
    this.price,
    required this.temperature,
    required this.stockStatus,
    required this.confidence,
    this.lastSeenAt,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
  });

  String get priceLabel => price == null ? '価格不明' : '$price円';

  String get distanceLabel {
    if (distanceKm == null) return '';
    return DistanceUtil.buildDistanceLabel(distanceKm!);
  }
}

class SearchRepository {
  SearchRepository({
    ProductRepository? productRepository,
    MachineRepository? machineRepository,
  })  : _productRepository = productRepository ?? ProductRepository(),
        _machineRepository = machineRepository ?? MachineRepository();

  final ProductRepository _productRepository;
  final MachineRepository _machineRepository;

  Future<List<SearchResultItem>> search({
    required String keyword,
    ProductCategory? category,
    ItemTemperature? temperatureFilter,
    double? currentLatitude,
    double? currentLongitude,
    SearchSortType sortType = SearchSortType.nearest,
  }) async {
    final List<Product> products = await _productRepository.fetchProducts(
      keyword: keyword,
      category: category,
      limit: 100,
    );

    if (products.isEmpty) {
      return <SearchResultItem>[];
    }

    final List<SearchResultItem> results = <SearchResultItem>[];

    for (final Product product in products) {
      final List<VendingMachineAccess> accesses =
      await _machineRepository.fetchMachineItemsByProductId(
        product.id,
        limit: 100,
      );

      for (final VendingMachineAccess access in accesses) {
        if (temperatureFilter != null &&
            temperatureFilter != ItemTemperature.unknown &&
            access.temperature != temperatureFilter &&
            access.temperature != ItemTemperature.both) {
          continue;
        }

        final VendingMachine? machine =
        await _machineRepository.fetchMachineById(access.machineId);

        if (machine == null || machine.status != MachineStatus.active) {
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
    }

    _sortResults(results, sortType);
    return results;
  }

  void _sortResults(List<SearchResultItem> results, SearchSortType sortType) {
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
          return aPrice.compareTo(bPrice);
        });
        return;
      case SearchSortType.bestMatch:
        results.sort((SearchResultItem a, SearchResultItem b) {
          return a.productName.compareTo(b.productName);
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
}