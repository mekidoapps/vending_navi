import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/content_blocking/application/blocked_content_state.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/models/vending_machine_detail_data.dart';
import 'package:vending_app/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import 'package:vending_app/features/vending_machine/domain/entities/public_machine_photo.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';
import 'package:vending_app/features/vending_machine/presentation/v2_vending_machine_detail_screen.dart';

void main() {
  testWidgets(
    'photo actor action routes the exact photo and filters only that photo after block',
    (tester) async {
      final gateway = _Gateway(mode: ContentBlockMode.actor);
      final route = _RouteCapture();
      await _pump(tester, gateway: gateway, route: route);

      await tester.tap(
        find.byKey(const Key('photoActions_p_0123456789abcdef0123456789abcd')),
      );
      await tester.pumpAndSettle();
      expect(find.text('この写真を報告'), findsOneWidget);
      expect(find.text('この投稿者のコンテンツを非表示'), findsOneWidget);

      await tester.tap(find.text('この写真を報告'));
      await tester.pumpAndSettle();
      expect(route.machineId, 'machine_detail_actions');
      expect(route.photoId, 'p_0123456789abcdef0123456789abcd');
      expect(route.productId, isNull);

    route.router.pop();
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('photoActions_p_0123456789abcdef0123456789abcd')),
      );
      await tester.pumpAndSettle();
    await tester.tap(find.text('この投稿者のコンテンツを非表示').last);
      await tester.pumpAndSettle();
      expect(
        gateway.changes.single,
        _Target(
          'photo',
          'machine_detail_actions',
          'p_0123456789abcdef0123456789abcd',
          null,
        ),
      );
      expect(
        find.byKey(const Key('formalPhoto_p_0123456789abcdef0123456789abcd')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('formalPhoto_p_abcdef0123456789abcdef0123456789')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'photo fallback and failure remain private and preserve other detail content',
    (tester) async {
      final gateway = _Gateway(
        mode: ContentBlockMode.content,
        failChange: true,
      );
      await _pump(tester, gateway: gateway);

      await tester.tap(
        find.byKey(const Key('photoActions_p_0123456789abcdef0123456789abcd')),
      );
      await tester.pumpAndSettle();
      expect(find.text('この写真を非表示'), findsOneWidget);
      expect(find.text('この投稿者のコンテンツを非表示'), findsNothing);
      await tester.tap(find.text('この写真を非表示'));
      await tester.pumpAndSettle();
      expect(find.text('この写真を非表示にできませんでした'), findsOneWidget);
      expect(
        find.byKey(const Key('formalPhoto_p_0123456789abcdef0123456789abcd')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('formalPhoto_p_abcdef0123456789abcdef0123456789')),
        findsOneWidget,
      );
      expect(find.textContaining('uid'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
    },
  );

  testWidgets(
    'product actor action routes exact product and filters only that product',
    (tester) async {
      final gateway = _Gateway(mode: ContentBlockMode.actor);
      final route = _RouteCapture();
      await _pump(tester, gateway: gateway, route: route);
      await _reveal(tester, find.byKey(const Key('productActions_product_a')));

      await tester.tap(find.byKey(const Key('productActions_product_a')));
      await tester.pumpAndSettle();
      expect(find.text('この商品情報を報告'), findsOneWidget);
      await tester.tap(find.text('この商品情報を報告'));
      await tester.pumpAndSettle();
      expect(route.machineId, 'machine_detail_actions');
      expect(route.productId, 'product_a');
      expect(route.photoId, isNull);

    await _pump(tester, gateway: gateway);
    await _reveal(tester, find.byKey(const Key('productActions_product_a')));
    await tester.tap(find.byKey(const Key('productActions_product_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('この投稿者のコンテンツを非表示').last);
      await tester.pumpAndSettle();
      expect(
        gateway.changes.single,
        _Target('product', 'machine_detail_actions', null, 'product_a'),
      );
      expect(find.byKey(const Key('detailProduct_product_a')), findsNothing);
      expect(find.byKey(const Key('detailProduct_product_b')), findsOneWidget);
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 500),
        1000,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('formalPhoto_p_0123456789abcdef0123456789abcd')),
        findsOneWidget,
      );
    },
  );

  testWidgets('product fallback action has no overflow on a small viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, gateway: _Gateway(mode: ContentBlockMode.content));

    await _reveal(tester, find.byKey(const Key('productActions_product_b')));
    await tester.tap(find.byKey(const Key('productActions_product_b')));
    await tester.pumpAndSettle();
    expect(find.text('この商品を非表示'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _Gateway gateway,
  _RouteCapture? route,
}) async {
  final data = _data();
  final router = GoRouter(
    initialLocation: '/machines/${data.machine.id.value}',
    routes: <RouteBase>[
      GoRoute(
        path: '/machines/:machineId',
        builder: (_, _) =>
            V2VendingMachineDetailScreen(machineId: data.machine.id),
      ),
      GoRoute(
        name: 'v2MachineReport',
        path: '/machines/:machineId/report',
        builder: (_, state) {
          route?.machineId = state.pathParameters['machineId'];
          route?.photoId = state.uri.queryParameters['photoId'];
          route?.productId = state.uri.queryParameters['productId'];
          return const Scaffold(body: Text('report target'));
        },
      ),
    ],
  );
  route?.router = router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_AuthRepository()),
        blockedContentGatewayProvider.overrideWithValue(gateway),
        vendingMachineDetailProvider(data.machine.id).overrideWithValue(
          AsyncValue<AppResult<VendingMachineDetailData>>.data(
            AppResult<VendingMachineDetailData>.success(data),
          ),
        ),
        formalMachinePhotoUrlProvider.overrideWith((ref, target) async => ''),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.fling(find.byType(Scrollable).first, const Offset(0, -500), 1000);
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pump();
}

VendingMachineDetailData _data() {
  final machine = VendingMachine(
    id: VendingMachineId.parse('machine_detail_actions'),
    schemaVersion: 2,
    name: 'テスト自販機',
    manufacturerStatus: ManufacturerStatus.unknown,
    location: GeoCoordinate(latitude: 35.68, longitude: 139.76),
    geohash: 'xn76',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.productsConfirmed,
  );
  return VendingMachineDetailData(
    machine: machine,
    manufacturerName: 'メーカー',
    photos: const <PublicMachinePhoto>[
      PublicMachinePhoto(
        photoId: 'p_0123456789abcdef0123456789abcd',
        status: 'active',
      ),
      PublicMachinePhoto(
        photoId: 'p_abcdef0123456789abcdef0123456789',
        status: 'active',
      ),
    ],
    products: <VendingMachineProductDetailItem>[
      VendingMachineProductDetailItem(
        productId: ProductId.parse('product_a'),
        productName: '商品A',
        evidenceType: ProductEvidenceType.manualConfirmed,
        availability: ProductAvailability.available,
      ),
      VendingMachineProductDetailItem(
        productId: ProductId.parse('product_b'),
        productName: '商品B',
        evidenceType: ProductEvidenceType.manufacturerInferred,
        availability: ProductAvailability.available,
      ),
    ],
  );
}

final class _Gateway implements BlockedContentGateway {
  _Gateway({required this.mode, this.failChange = false});
  final ContentBlockMode mode;
  final bool failChange;
  final List<_Target> changes = <_Target>[];

  @override
  Future<void> change({
    required String operation,
    required Map<String, Object?> data,
  }) async {
    if (failChange) throw StateError('private');
    changes.add(
      _Target(
        data['targetType']! as String,
        data['machineId']! as String,
        data['photoId'] as String?,
        data['productId'] as String?,
      ),
    );
  }

  @override
  Future<Object?> getBlockedContentIds() async {
    return <String, Object?>{
      'machineIds': const <String>[],
      'photoIds': changes
          .where((target) => target.photoId != null)
          .map((target) => target.photoId)
          .toList(),
      'productIds': changes
          .where((target) => target.productId != null)
          .map((target) => target.productId)
          .toList(),
    };
  }

  @override
  Future<Object?> resolveContentBlockMode(Map<String, Object?> data) async =>
      <String, Object?>{'blockMode': mode.name};
}

final class _Target {
  const _Target(this.type, this.machineId, this.photoId, this.productId);
  final String type;
  final String machineId;
  final String? photoId;
  final String? productId;
  @override
  bool operator ==(Object other) =>
      other is _Target &&
      other.type == type &&
      other.machineId == machineId &&
      other.photoId == photoId &&
      other.productId == productId;
  @override
  int get hashCode => Object.hash(type, machineId, photoId, productId);
}

final class _RouteCapture {
  late GoRouter router;
  String? machineId;
  String? photoId;
  String? productId;
}

final class _AuthRepository implements AuthRepository {
  @override
  AuthSession get currentSession => const GuestAuthSession();
  @override
  Stream<AuthSession> watchSession() =>
      Stream<AuthSession>.value(const GuestAuthSession());
  @override
  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<AppResult<bool>> reauthenticateWithPassword({
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<AppResult<bool>> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();
  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<AppResult<AuthSession>> signOut() => throw UnimplementedError();
}
