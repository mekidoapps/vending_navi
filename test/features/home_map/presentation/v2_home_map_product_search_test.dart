import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/home_map/presentation/v2_home_map_screen.dart';
import 'package:vending_app/features/location/application/providers/location_service_provider.dart';
import 'package:vending_app/features/location/domain/entities/app_location_permission.dart';
import 'package:vending_app/features/location/domain/entities/current_location.dart';
import 'package:vending_app/features/location/domain/services/location_service.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/repositories/product_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/product_search/application/providers/product_search_providers.dart';
import 'package:vending_app/features/product_search/domain/services/product_candidate_search_service.dart';

void main() {
  testWidgets('探すからパネルを開き商品選択後に小ラベルを残す', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
          productCandidateSearchServiceProvider.overrideWithValue(
            ProductCandidateSearchService(
              productRepository: _FixtureProductRepository(),
            ),
          ),
        ],
        child: MaterialApp(
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) =>
                const ColoredBox(key: Key('fakeMap'), color: Colors.white),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('searchMapAction')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('productSearchPanel')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('productSearchField')), '綾鷹');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final product = ProductMasterFixture.products.firstWhere(
      (item) => item.name == '綾鷹',
    );

    await tester.tap(find.byKey(Key('productCandidate_${product.id.value}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('productSearchPanel')), findsNothing);
    expect(find.byKey(const Key('selectedProductLabel')), findsOneWidget);
    expect(find.text('綾鷹'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearSelectedProduct')));
    await tester.pump();

    expect(find.byKey(const Key('selectedProductLabel')), findsNothing);
  });

  testWidgets('小型画面でも検索パネルでoverflowしない', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(_FakeLocationService()),
        ],
        child: MaterialApp(
          home: V2HomeMapScreen(
            autoLocate: false,
            mapBuilder: (_) =>
                const ColoredBox(key: Key('fakeMap'), color: Colors.white),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('searchMapAction')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('productSearchPanel')), findsOneWidget);
    expect(find.byKey(const Key('productSearchField')), findsOneWidget);
  });
}

final class _FakeLocationService implements LocationService {
  @override
  Future<AppLocationPermission> checkPermission() async {
    return AppLocationPermission.whileInUse;
  }

  @override
  Future<AppResult<CurrentLocation>> getCurrentLocation() async {
    return AppResult<CurrentLocation>.success(
      CurrentLocation(
        latitude: 35.68,
        longitude: 139.76,
        accuracyMeters: 10,
        capturedAt: DateTime.utc(2026, 8, 7),
      ),
    );
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<AppLocationPermission> requestPermission() async {
    return AppLocationPermission.whileInUse;
  }
}

final class _FixtureProductRepository implements ProductRepository {
  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    for (final product in ProductMasterFixture.products) {
      if (product.id == id) {
        return AppResult<Product>.success(product);
      }
    }
    return const AppResult<Product>.failure(NotFoundFailure());
  }

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    return AppResult<List<Product>>.success(
      ProductMasterFixture.products
          .where((product) => !activeOnly || product.isActive)
          .toList(growable: false),
    );
  }
}
