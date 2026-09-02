import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vending_app/app/router/app_route.dart';
import 'package:vending_app/app/router/app_router.dart';
import 'package:vending_app/app/router/entry_mode.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/home_map/application/providers/vending_machine_map_providers.dart';
import 'package:vending_app/features/home_map/domain/repositories/vending_machine_map_repository.dart';
import 'package:vending_app/features/home_map/domain/value_objects/map_viewport_bounds.dart';
import 'package:vending_app/features/home_map/presentation/v2_home_map_screen.dart';
import 'package:vending_app/features/location/application/providers/location_service_provider.dart';
import 'package:vending_app/features/location/domain/entities/app_location_permission.dart';
import 'package:vending_app/features/location/domain/entities/current_location.dart';
import 'package:vending_app/features/location/domain/services/location_service.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_state.dart';
import 'package:vending_app/features/machine_registration/application/providers/machine_registration_providers.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_draft.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_result.dart';
import 'package:vending_app/features/machine_registration/domain/repositories/machine_registration_repository.dart';
import 'package:vending_app/features/product_master/application/providers/product_master_providers.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/repositories/manufacturer_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/domain/entities/vending_machine.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets(
    'P10-I02 未ログインから認証復帰してメーカー簡単登録後に詳細へ進む',
    (WidgetTester tester) async {
      final authRepository = _FakeAuthRepository(
        session: const GuestAuthSession(),
      );
      final registrationRepository =
          _FakeMachineRegistrationRepository();
      final manufacturer = _manufacturer();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            authRepository,
          ),
          locationServiceProvider.overrideWithValue(
            _FakeLocationService(),
          ),
          vendingMachineMapRepositoryProvider.overrideWithValue(
            const _EmptyMapRepository(),
          ),
          machineRegistrationRepositoryProvider.overrideWithValue(
            registrationRepository,
          ),
          manufacturerRepositoryProvider.overrideWithValue(
            _FakeManufacturerRepository(
              <Manufacturer>[manufacturer],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      var authenticationRequestCount = 0;

      final router = createAppRouter(
        entryMode: AppEntryMode.v2,

        // Home itself is real.
        // Only Firebase/Maps dependencies are replaced for this test.
        v2Builder: (context) {
          return Consumer(
            builder: (context, ref, _) {
              return V2HomeMapScreen(
                autoLocate: false,
                mapBuilder: (_) => const ColoredBox(
                  key: Key('p10RegistrationFakeMap'),
                  color: Colors.white,
                ),
                authenticationRequester: () async {
                  authenticationRequestCount += 1;
                  authRepository.session =
                      _authenticatedSession();
                  return true;
                },
                onRegisterPressed: () {
                  ref
                      .read(
                        machineRegistrationControllerProvider
                            .notifier,
                      )
                      .reset();

                  context.pushNamed(
                    AppRoute.v2RegistrationPosition.name,
                  );
                },
              );
            },
          );
        },

        // Google Maps platform view is not part of this integration
        // boundary. Position selection itself already has Widget tests.
        registrationPositionBuilder: (context) {
          return Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const Key(
                      'p10RegistrationPositionContinue',
                    ),
                    onPressed: () {
                      final registration = ref.read(
                        machineRegistrationControllerProvider
                            .notifier,
                      );

                      registration.setLocation(
                        GeoCoordinate(
                          latitude: 35.68123,
                          longitude: 139.76789,
                        ),
                      );

                      final continued =
                          registration.continueFromPosition();

                      if (!continued) {
                        return;
                      }

                      context.pushNamed(
                        AppRoute
                            .v2RegistrationDuplicates
                            .name,
                      );
                    },
                    child: const Text('位置を確定'),
                  ),
                ),
              );
            },
          );
        },

        machineDetailBuilder: (_, machineId) {
          return Scaffold(
            key: const Key('p10CreatedMachineDetail'),
            body: Center(
              child: Text(
                'created-detail:${machineId.value}',
              ),
            ),
          );
        },
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

      expect(
        authRepository.currentSession,
        isA<GuestAuthSession>(),
      );

      //
      // Home -> auth gate -> original registration action resumes.
      //
      await tester.tap(
        find.byKey(const Key('registerMapAction')),
      );
      await tester.pumpAndSettle();

      expect(authenticationRequestCount, 1);
      expect(
        authRepository.currentSession,
        isA<AuthenticatedAuthSession>(),
      );

      expect(
        find.byKey(
          const Key('p10RegistrationPositionContinue'),
        ),
        findsOneWidget,
      );

      //
      // Position -> duplicate check.
      //
      await tester.tap(
        find.byKey(
          const Key('p10RegistrationPositionContinue'),
        ),
      );
      await tester.pumpAndSettle();

      // Empty duplicate result automatically continues to method.
      expect(
        find.byKey(
          const Key('registrationManufacturerMethodButton'),
        ),
        findsOneWidget,
      );

      expect(
        container
            .read(machineRegistrationControllerProvider)
            .step,
        MachineRegistrationStep.method,
      );

      //
      // Method -> manufacturer.
      //
      await tester.tap(
        find.byKey(
          const Key('registrationManufacturerMethodButton'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('registrationManufacturer_coca_cola'),
        ),
        findsOneWidget,
      );

      //
      // Manufacturer -> confirmation.
      //
      await tester.tap(
        find.byKey(
          const Key('registrationManufacturer_coca_cola'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('登録内容の確認'),
        findsOneWidget,
      );
      expect(
        find.text('コカ・コーラ'),
        findsOneWidget,
      );
      expect(
        find.textContaining('代表商品 1件'),
        findsOneWidget,
      );

      final beforeSubmit =
          container.read(
            machineRegistrationControllerProvider,
          );

      expect(
        beforeSubmit.draft.manufacturerId?.value,
        'coca_cola',
      );
      expect(
        beforeSubmit.draft.location?.latitude,
        35.68123,
      );

      //
      // Confirmation -> fake Callable repository -> created detail.
      //
      await tester.scrollUntilVisible(
        find.byKey(
          const Key('registrationConfirmationSubmitButton'),
        ),
        300,
      );

      await tester.tap(
        find.byKey(
          const Key('registrationConfirmationSubmitButton'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        registrationRepository.callCount,
        1,
      );
      expect(
        registrationRepository
            .lastDraft
            ?.manufacturerId
            ?.value,
        'coca_cola',
      );
      expect(
        registrationRepository
            .lastDraft
            ?.location
            ?.latitude,
        35.68123,
      );

      expect(
        find.byKey(
          const Key('p10CreatedMachineDetail'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'created-detail:machine_p10_created',
        ),
        findsOneWidget,
      );

      // Production router resets the draft only after capturing
      // the created machine ID and navigating back to detail.
      final afterCompleted =
          container.read(
            machineRegistrationControllerProvider,
          );

      expect(
        afterCompleted.step,
        MachineRegistrationStep.position,
      );
      expect(
        afterCompleted.createdMachineId,
        isNull,
      );
    },
  );
}

AuthSession _authenticatedSession() {
  return AuthenticatedAuthSession(
    AuthUser(
      uid: 'p10_registration_user',
      email: 'p10@example.com',
      displayName: null,
      providerIds: const <String>['password'],
      emailVerified: true,
    ),
  );
}

Manufacturer _manufacturer() {
  return Manufacturer(
    id: ManufacturerId.parse('coca_cola'),
    name: 'コカ・コーラ',
    displayShortName: 'コカ・コーラ',
    presetProductIds: <ProductId>[
      ProductId.parse('ayataka_regular'),
    ],
    createdAt: DateTime.utc(2026, 8, 21),
    updatedAt: DateTime.utc(2026, 8, 21),
  );
}

final class _FakeMachineRegistrationRepository
    implements MachineRegistrationRepository {
  int callCount = 0;
  MachineRegistrationDraft? lastDraft;

  @override
  Future<AppResult<MachineRegistrationResult>>
  createVendingMachine(
    MachineRegistrationDraft draft,
  ) async {
    callCount += 1;
    lastDraft = draft;

    return AppResult<MachineRegistrationResult>.success(
      MachineRegistrationResult(
        machineId:
            VendingMachineId.parse('machine_p10_created'),
        created: true,
      ),
    );
  }
}

final class _FakeManufacturerRepository
    implements ManufacturerRepository {
  const _FakeManufacturerRepository(
    this.manufacturers,
  );

  final List<Manufacturer> manufacturers;

  @override
  Future<AppResult<List<Manufacturer>>> getManufacturers({
    bool activeOnly = true,
  }) async {
    return AppResult<List<Manufacturer>>.success(
      manufacturers,
    );
  }

  @override
  Future<AppResult<Manufacturer>> getManufacturer(
    ManufacturerId id,
  ) async {
    final manufacturer = manufacturers.firstWhere(
      (item) => item.id == id,
    );

    return AppResult<Manufacturer>.success(
      manufacturer,
    );
  }
}

final class _EmptyMapRepository
    implements VendingMachineMapRepository {
  const _EmptyMapRepository();

  @override
  Future<AppResult<List<VendingMachine>>>
  getMachinesInViewport(
    MapViewportBounds bounds,
  ) async {
    return const AppResult<List<VendingMachine>>.success(
      <VendingMachine>[],
    );
  }
}

final class _FakeAuthRepository
    implements AuthRepository {
  _FakeAuthRepository({
    required this.session,
  });

  AuthSession session;

  @override
  AuthSession get currentSession => session;

  @override
  Stream<AuthSession> watchSession() {
    return Stream<AuthSession>.value(session);
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
    session = const GuestAuthSession();

    return AppResult<AuthSession>.success(
      session,
    );
  }

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({
    required String email,
  }) {
    throw UnimplementedError();
  }
}

final class _FakeLocationService
    implements LocationService {
  @override
  Future<AppLocationPermission> checkPermission() async {
    return AppLocationPermission.whileInUse;
  }

  @override
  Future<AppResult<CurrentLocation>>
  getCurrentLocation() async {
    return AppResult<CurrentLocation>.success(
      CurrentLocation(
        latitude: 35.68,
        longitude: 139.76,
        accuracyMeters: 10,
        capturedAt: DateTime.utc(2026, 8, 21),
      ),
    );
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    return true;
  }

  @override
  Future<AppLocationPermission>
  requestPermission() async {
    return AppLocationPermission.whileInUse;
  }
}
