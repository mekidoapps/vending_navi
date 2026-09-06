import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/machine_update/application/providers/machine_product_update_providers.dart';
import 'package:vending_app/features/machine_update/domain/models/machine_product_update_draft.dart';
import 'package:vending_app/features/machine_update/domain/models/machine_product_update_result.dart';
import 'package:vending_app/features/machine_update/domain/repositories/machine_product_update_repository.dart';
import 'package:vending_app/features/machine_update/domain/services/machine_product_update_request_id_generator.dart';
import 'package:vending_app/features/ugc_terms/presentation/ugc_terms_gate.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/application/models/vending_machine_detail_data.dart';
import 'package:vending_app/features/vending_machine/application/providers/vending_machine_detail_providers.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_enums.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine_product.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets(
    'P10-I04 詳細から手動商品更新で売り切れに変更しsubmit後に詳細へ戻る',
    (WidgetTester tester) async {
      final data = _detailData();
      final machineId = data.machine.id;
      final updateRepository = _FakeProductUpdateRepository(machineId);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _AuthenticatedRepository(),
          ),
          vendingMachineDetailProvider(machineId).overrideWithValue(
            AsyncValue<AppResult<VendingMachineDetailData>>.data(
              AppResult<VendingMachineDetailData>.success(data),
            ),
          ),
          machineProductUpdateRepositoryProvider.overrideWithValue(
            updateRepository,
          ),
          machineProductUpdateRequestIdGeneratorProvider.overrideWithValue(
            const _RequestIdGenerator(),
          ),
          ugcTermsConsentServiceProvider.overrideWithValue(
            const _AcceptedTermsConsentService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = createAppRouter(
        entryMode: AppEntryMode.v2,
        v2Builder: (_) => const Scaffold(
          body: Text('P10 home'),
        ),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      //
      // Open the real machine detail route.
      //
      router.go('/v2/machines/${machineId.value}');
      await tester.pumpAndSettle();

      expect(find.text('駅前の自販機'), findsOneWidget);
      expect(find.text('BOSS ブラック'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('machineInfoUpdateButton')),
        300,
      );

      expect(
        find.byKey(const Key('machineInfoUpdateButton')),
        findsOneWidget,
      );

      //
      // Detail -> authenticated update menu.
      //
      await tester.tap(
        find.byKey(const Key('machineInfoUpdateButton')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('manualProductUpdateMenuItem')),
        findsOneWidget,
      );

      //
      // Update menu -> manual product update.
      //
      await tester.tap(
        find.byKey(const Key('manualProductUpdateMenuItem')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('manualProductUpdateScreen')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'manualProductCurrent_suntory_boss_black',
          ),
        ),
        findsOneWidget,
      );

      //
      // Confirmed + available -> sold out.
      //
      await tester.tap(
        find.byKey(
          const Key(
            'toggleSoldOut_suntory_boss_black',
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(
          const Key(
            'pendingProductUpdate_suntory_boss_black',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('売り切れに変更予定'),
        findsOneWidget,
      );

      //
      // Manual edit -> confirmation.
      //
      await tester.scrollUntilVisible(
        find.byKey(
          const Key('reviewMachineProductChangesButton'),
        ),
        250,
      );

      await tester.tap(
        find.byKey(
          const Key('reviewMachineProductChangesButton'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('productUpdateConfirmationScreen'),
        ),
        findsOneWidget,
      );
      expect(find.text('BOSS ブラック'), findsOneWidget);

      //
      // Confirmation -> fake Callable repository -> detail.
      //
      await tester.tap(
        find.byKey(
          const Key('submitMachineProductUpdateButton'),
        ),
      );
      await tester.pumpAndSettle();

      expect(updateRepository.callCount, 1);
      expect(
        updateRepository.lastRequestId,
        '123e4567-e89b-42d3-a456-426614174099',
      );
      expect(
        updateRepository.lastDraft?.machineId,
        machineId,
      );
      expect(
        updateRepository.lastDraft?.operations.length,
        1,
      );
      expect(
        updateRepository
            .lastDraft
            ?.productNames['suntory_boss_black'],
        'BOSS ブラック',
      );

      //
      // Production router returns to detail and invalidates detail state.
      //
      expect(find.text('自販機詳細'), findsOneWidget);
      expect(
        find.byKey(const Key('productUpdateConfirmationScreen')),
        findsNothing,
      );
    },
  );
}

final class _AcceptedTermsConsentService implements UgcTermsConsentService {
  const _AcceptedTermsConsentService();

  @override
  Future<void> acceptCurrentTerms() async {}

  @override
  Future<bool> hasAcceptedCurrentTerms() async => true;
}

VendingMachineDetailData _detailData() {
  final machine = VendingMachine(
    id: VendingMachineId.parse('machine_p10_update'),
    schemaVersion: 2,
    name: '駅前の自販機',
    manufacturerId: ManufacturerId.parse('suntory'),
    manufacturerStatus: ManufacturerStatus.confirmed,
    location: GeoCoordinate(
      latitude: 35.681236,
      longitude: 139.767125,
    ),
    geohash: 'xn76ur',
    placeDescription: '駅東口の壁沿い',
    installationType: InstallationType.outdoor,
    status: VendingMachineStatus.active,
    dataLevel: VendingMachineDataLevel.productsConfirmed,
    createdBy: 'p10_test',
    products: <VendingMachineProduct>[
      VendingMachineProduct(
        productId: ProductId.parse('suntory_boss_black'),
        evidenceType: ProductEvidenceType.manualConfirmed,
        availability: ProductAvailability.available,
      ),
      VendingMachineProduct(
        productId: ProductId.parse('suntory_tennensui'),
        evidenceType: ProductEvidenceType.manufacturerInferred,
        availability: ProductAvailability.unknown,
      ),
    ],
  );

  return VendingMachineDetailData(
    machine: machine,
    manufacturerName: 'サントリー',
    products: <VendingMachineProductDetailItem>[
      VendingMachineProductDetailItem(
        productId: ProductId.parse('suntory_boss_black'),
        productName: 'BOSS ブラック',
        evidenceType: ProductEvidenceType.manualConfirmed,
        availability: ProductAvailability.available,
      ),
      VendingMachineProductDetailItem(
        productId: ProductId.parse('suntory_tennensui'),
        productName: 'サントリー天然水',
        evidenceType: ProductEvidenceType.manufacturerInferred,
        availability: ProductAvailability.unknown,
      ),
    ],
  );
}

final class _FakeProductUpdateRepository
    implements MachineProductUpdateRepository {
  _FakeProductUpdateRepository(this.machineId);

  final VendingMachineId machineId;

  int callCount = 0;
  String? lastRequestId;
  MachineProductUpdateDraft? lastDraft;

  @override
  Future<AppResult<MachineProductUpdateResult>> updateProducts({
    required String requestId,
    required MachineProductUpdateDraft draft,
  }) async {
    callCount += 1;
    lastRequestId = requestId;
    lastDraft = draft;

    return AppResult<MachineProductUpdateResult>.success(
      MachineProductUpdateResult(
        machineId: machineId,
        updated: true,
        changedProductIds: const <String>[
          'suntory_boss_black',
        ],
      ),
    );
  }
}

final class _RequestIdGenerator
    implements MachineProductUpdateRequestIdGenerator {
  const _RequestIdGenerator();

  @override
  String next() {
    return '123e4567-e89b-42d3-a456-426614174099';
  }
}

final class _AuthenticatedRepository
    implements AuthRepository {
  final AuthSession _session = AuthenticatedAuthSession(
    AuthUser(
      uid: 'p10_update_user',
      email: 'p10-update@example.com',
      displayName: null,
      providerIds: const <String>['password'],
      emailVerified: true,
    ),
  );

  @override
  AuthSession get currentSession => _session;

  @override
  Stream<AuthSession> watchSession() {
    return Stream<AuthSession>.value(_session);
  }

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AppResult<bool>> reauthenticateWithPassword({
    required String password,
  }) async {
    return const AppResult<bool>.success(true);
  }

  @override
  Future<AppResult<AuthSession>> signOut() async {
    return const AppResult<AuthSession>.success(
      GuestAuthSession(),
    );
  }

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({
    required String email,
  }) {
    throw UnimplementedError();
  }
}
