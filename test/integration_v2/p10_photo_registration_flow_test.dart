import 'dart:convert';
import 'dart:typed_data';

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
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_state.dart';
import 'package:vending_app/features/machine_registration/application/providers/machine_registration_providers.dart';
import 'package:vending_app/features/machine_registration/application/registration_photo_recognition_controller.dart';
import 'package:vending_app/features/machine_registration/application/registration_photo_recognition_state.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_draft.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_result.dart';
import 'package:vending_app/features/machine_registration/domain/entities/photo_recognition_result.dart';
import 'package:vending_app/features/machine_registration/domain/models/normalized_registration_photo.dart';
import 'package:vending_app/features/machine_registration/domain/models/temporary_registration_photo_upload.dart';
import 'package:vending_app/features/machine_registration/domain/repositories/machine_registration_repository.dart';
import 'package:vending_app/features/machine_registration/domain/repositories/photo_recognition_repository.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_photo_capture_source.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_photo_normalizer.dart';
import 'package:vending_app/features/machine_registration/domain/services/temporary_registration_photo_uploader.dart';
import 'package:vending_app/features/product_master/application/providers/product_master_providers.dart';
import 'package:vending_app/features/product_master/data/fixtures/product_master_fixture.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/entities/product.dart';
import 'package:vending_app/features/product_master/domain/repositories/manufacturer_repository.dart';
import 'package:vending_app/features/product_master/domain/repositories/product_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/vending_machine_id.dart';

void main() {
  testWidgets('P10-I03A 写真取得からAI候補を確認して正式登録後に詳細へ進む', (
    WidgetTester tester,
  ) async {
    final registrationRepository = _FakeMachineRegistrationRepository();
    final recognitionRepository = _FakePhotoRecognitionRepository(
      status: PhotoRecognitionStatus.completed,
    );
    final manufacturer = _manufacturer();
    final products = _products();

    final container = _createContainer(
      registrationRepository: registrationRepository,
      recognitionRepository: recognitionRepository,
      manufacturer: manufacturer,
      products: products,
    );
    addTearDown(container.dispose);

    _prepareMethodStep(container);

    final router = _createRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go(AppRoute.v2RegistrationMethod.path);
    await tester.pumpAndSettle();

    expect(
      container.read(machineRegistrationControllerProvider).step,
      MachineRegistrationStep.method,
    );

    //
    // Method -> photo.
    //
    await tester.tap(find.byKey(const Key('registrationPhotoMethodButton')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('registrationPhotoCaptureButton')),
      findsOneWidget,
    );

    //
    // Capture -> normalize -> temporary upload -> AI candidates.
    //
    await tester.tap(find.byKey(const Key('registrationPhotoCaptureButton')));
    await tester.pumpAndSettle();

    expect(recognitionRepository.callCount, 1);

    final draftAfterUpload = container
        .read(machineRegistrationControllerProvider)
        .draft;

    expect(draftAfterUpload.temporaryPhotoUploadId, isNotNull);
    expect(
      recognitionRepository.lastUploadId,
      draftAfterUpload.temporaryPhotoUploadId,
    );

    expect(
      container.read(registrationPhotoRecognitionControllerProvider).stage,
      RegistrationPhotoRecognitionStage.ready,
    );

    expect(find.text('AIが見つけた候補です'), findsOneWidget);
    expect(find.text('サントリー'), findsWidgets);
    expect(find.text(products.single.name), findsOneWidget);

    //
    // Human confirmation of AI candidates.
    //
    await tester.scrollUntilVisible(
      find.byKey(const Key('registrationPhotoCandidatesSaveButton')),
      300,
    );

    await tester.tap(
      find.byKey(const Key('registrationPhotoCandidatesSaveButton')),
    );
    await tester.pumpAndSettle();

    final confirmed = container.read(machineRegistrationControllerProvider);

    expect(confirmed.step, MachineRegistrationStep.confirm);
    expect(confirmed.draft.manufacturerId?.value, 'suntory');
    expect(
      confirmed.draft.confirmedProductIds.map((item) => item.value),
      contains('suntory_boss_black'),
    );

    expect(find.text('登録内容の確認'), findsOneWidget);
    expect(
      find.byKey(const Key('registrationConfirmationProductSummary')),
      findsOneWidget,
    );

    //
    // Final confirmation -> create -> detail.
    //
    await _submitAndExpectDetail(tester, registrationRepository);

    expect(registrationRepository.lastDraft?.manufacturerId?.value, 'suntory');
    expect(
      registrationRepository.lastDraft?.confirmedProductIds.map(
        (item) => item.value,
      ),
      contains('suntory_boss_black'),
    );
    expect(registrationRepository.lastDraft?.temporaryPhotoUploadId, isNotNull);
  });

  testWidgets('P10-I03B AI認識失敗後にメーカー登録へ切り替えて正式登録できる', (
    WidgetTester tester,
  ) async {
    final registrationRepository = _FakeMachineRegistrationRepository();
    final recognitionRepository = _FakePhotoRecognitionRepository(
      status: PhotoRecognitionStatus.failed,
    );
    final manufacturer = _manufacturer();
    final products = _products();

    final container = _createContainer(
      registrationRepository: registrationRepository,
      recognitionRepository: recognitionRepository,
      manufacturer: manufacturer,
      products: products,
    );
    addTearDown(container.dispose);

    _prepareMethodStep(container);

    final router = _createRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go(AppRoute.v2RegistrationMethod.path);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registrationPhotoMethodButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registrationPhotoCaptureButton')));
    await tester.pumpAndSettle();

    expect(recognitionRepository.callCount, 1);
    expect(
      container.read(registrationPhotoRecognitionControllerProvider).stage,
      RegistrationPhotoRecognitionStage.failed,
    );

    expect(find.text('写真から候補を見つけられませんでした'), findsOneWidget);
    expect(find.text('メーカーから登録する'), findsOneWidget);

    //
    // AI failure -> manufacturer fallback.
    //
    await tester.tap(find.text('メーカーから登録する'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('registrationManufacturer_suntory')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('registrationManufacturer_suntory')));
    await tester.pumpAndSettle();

    final fallbackState = container.read(machineRegistrationControllerProvider);

    expect(fallbackState.step, MachineRegistrationStep.confirm);
    expect(fallbackState.draft.manufacturerId?.value, 'suntory');

    expect(find.text('登録内容の確認'), findsOneWidget);

    await _submitAndExpectDetail(tester, registrationRepository);

    expect(registrationRepository.lastDraft?.manufacturerId?.value, 'suntory');
  });
}

ProviderContainer _createContainer({
  required _FakeMachineRegistrationRepository registrationRepository,
  required _FakePhotoRecognitionRepository recognitionRepository,
  required Manufacturer manufacturer,
  required List<Product> products,
}) {
  return ProviderContainer(
    overrides: [
      machineRegistrationRepositoryProvider.overrideWithValue(
        registrationRepository,
      ),
      registrationPhotoCaptureSourceProvider.overrideWithValue(
        _FakePhotoCaptureSource(),
      ),
      registrationPhotoNormalizerProvider.overrideWithValue(
        const _FakePhotoNormalizer(),
      ),
      temporaryRegistrationPhotoUploaderProvider.overrideWithValue(
        const _FakeTemporaryPhotoUploader(),
      ),
      photoRecognitionRepositoryProvider.overrideWithValue(
        recognitionRepository,
      ),
      manufacturerRepositoryProvider.overrideWithValue(
        _FakeManufacturerRepository(<Manufacturer>[manufacturer]),
      ),
      productRepositoryProvider.overrideWithValue(
        _FakeProductRepository(products),
      ),
      authRepositoryProvider.overrideWithValue(
        _AuthenticatedFakeAuthRepository(),
      ),
    ],
  );
}

void _prepareMethodStep(ProviderContainer container) {
  final controller = container.read(
    machineRegistrationControllerProvider.notifier,
  );

  controller.setLocation(
    GeoCoordinate(latitude: 35.68123, longitude: 139.76789),
  );

  expect(controller.continueFromPosition(), isTrue);
  controller.continueAfterDuplicateCheck();

  expect(
    container.read(machineRegistrationControllerProvider).step,
    MachineRegistrationStep.method,
  );
}

GoRouter _createRouter() {
  return createAppRouter(
    entryMode: AppEntryMode.v2,
    v2Builder: (_) => const Scaffold(body: Text('P10 home')),
    machineDetailBuilder: (_, machineId) {
      return Scaffold(
        key: const Key('p10PhotoCreatedMachineDetail'),
        body: Center(child: Text('photo-created-detail:${machineId.value}')),
      );
    },
  );
}

Future<void> _submitAndExpectDetail(
  WidgetTester tester,
  _FakeMachineRegistrationRepository registrationRepository,
) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('registrationConfirmationSubmitButton')),
    300,
  );

  await tester.tap(
    find.byKey(const Key('registrationConfirmationSubmitButton')),
  );
  await tester.pumpAndSettle();

  expect(registrationRepository.callCount, 1);

  expect(find.byKey(const Key('p10PhotoCreatedMachineDetail')), findsOneWidget);

  expect(
    find.text('photo-created-detail:machine_p10_photo_created'),
    findsOneWidget,
  );
}

Manufacturer _manufacturer() {
  return Manufacturer(
    id: ManufacturerId.parse('suntory'),
    name: 'サントリーフーズ',
    displayShortName: 'サントリー',
    presetProductIds: <ProductId>[ProductId.parse('suntory_boss_black')],
    createdAt: DateTime.utc(2026, 8, 21),
    updatedAt: DateTime.utc(2026, 8, 21),
  );
}

List<Product> _products() {
  return ProductMasterFixture.products
      .where((product) => product.id.value == 'suntory_boss_black')
      .toList(growable: false);
}

final class _FakePhotoCaptureSource implements RegistrationPhotoCaptureSource {
  @override
  Future<Uint8List?> capture() async {
    // Valid 1x1 PNG. The test boundary is capture/normalization flow,
    // not the platform camera or JPEG encoder.
    return Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
        'CAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
        'AgUBAO+X2ioAAAAASUVORK5CYII=',
      ),
    );
  }
}

final class _FakePhotoNormalizer implements RegistrationPhotoNormalizer {
  const _FakePhotoNormalizer();

  @override
  Future<NormalizedRegistrationPhoto> normalize(Uint8List sourceBytes) async {
    return NormalizedRegistrationPhoto(bytes: sourceBytes, width: 1, height: 1);
  }
}

final class _FakeTemporaryPhotoUploader
    implements TemporaryRegistrationPhotoUploader {
  const _FakeTemporaryPhotoUploader();

  @override
  Future<TemporaryRegistrationPhotoUpload> upload({
    required String uploadId,
    required Uint8List jpegBytes,
  }) async {
    return TemporaryRegistrationPhotoUpload(
      uploadId: uploadId,
      objectPath: 'machine_uploads/p10/$uploadId.jpg',
    );
  }
}

final class _FakePhotoRecognitionRepository
    implements PhotoRecognitionRepository {
  _FakePhotoRecognitionRepository({required this.status});

  final PhotoRecognitionStatus status;

  int callCount = 0;
  String? lastUploadId;

  @override
  Future<AppResult<PhotoRecognitionResult>> recognize({
    required String recognitionRequestId,
    required String uploadId,
  }) async {
    callCount += 1;
    lastUploadId = uploadId;

    return AppResult<PhotoRecognitionResult>.success(
      PhotoRecognitionResult(
        manufacturerCandidateIds: status == PhotoRecognitionStatus.completed
            ? <ManufacturerId>[ManufacturerId.parse('suntory')]
            : const <ManufacturerId>[],
        productCandidateIds: status == PhotoRecognitionStatus.completed
            ? <ProductId>[ProductId.parse('suntory_boss_black')]
            : const <ProductId>[],
        unresolvedLabels: const <String>[],
        status: status,
      ),
    );
  }
}

final class _FakeMachineRegistrationRepository
    implements MachineRegistrationRepository {
  int callCount = 0;
  MachineRegistrationDraft? lastDraft;

  @override
  Future<AppResult<MachineRegistrationResult>> createVendingMachine(
    MachineRegistrationDraft draft,
  ) async {
    callCount += 1;
    lastDraft = draft;

    return AppResult<MachineRegistrationResult>.success(
      MachineRegistrationResult(
        machineId: VendingMachineId.parse('machine_p10_photo_created'),
        created: true,
      ),
    );
  }
}

final class _AuthenticatedFakeAuthRepository implements AuthRepository {
  final AuthSession _session = AuthenticatedAuthSession(
    AuthUser(
      uid: 'p10-photo-user',
      email: 'p10-photo@example.com',
      displayName: null,
      providerIds: const <String>['password'],
      emailVerified: true,
    ),
  );

  @override
  AuthSession get currentSession => _session;

  @override
  Stream<AuthSession> watchSession() => Stream<AuthSession>.value(_session);

  @override
  Future<AppResult<AuthSession>> registerWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> signOut() => throw UnimplementedError();

  @override
  Future<AppResult<bool>> reauthenticateWithPassword({
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AppResult<bool>> sendPasswordResetEmail({required String email}) =>
      throw UnimplementedError();
}

final class _FakeManufacturerRepository implements ManufacturerRepository {
  const _FakeManufacturerRepository(this.manufacturers);

  final List<Manufacturer> manufacturers;

  @override
  Future<AppResult<List<Manufacturer>>> getManufacturers({
    bool activeOnly = true,
  }) async {
    return AppResult<List<Manufacturer>>.success(manufacturers);
  }

  @override
  Future<AppResult<Manufacturer>> getManufacturer(ManufacturerId id) async {
    final manufacturer = manufacturers.firstWhere((item) => item.id == id);

    return AppResult<Manufacturer>.success(manufacturer);
  }
}

final class _FakeProductRepository implements ProductRepository {
  const _FakeProductRepository(this.products);

  final List<Product> products;

  @override
  Future<AppResult<List<Product>>> getProducts({bool activeOnly = true}) async {
    return AppResult<List<Product>>.success(products);
  }

  @override
  Future<AppResult<Product>> getProduct(ProductId id) async {
    final product = products.firstWhere((item) => item.id == id);

    return AppResult<Product>.success(product);
  }
}
