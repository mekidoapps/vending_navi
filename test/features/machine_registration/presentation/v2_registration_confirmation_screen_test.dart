import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/application/manufacturer_selection_controller.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_confirmation_screen.dart';
import 'package:vending_app/features/product_master/application/providers/product_master_providers.dart';
import 'package:vending_app/features/product_master/domain/entities/manufacturer.dart';
import 'package:vending_app/features/product_master/domain/repositories/manufacturer_repository.dart';
import 'package:vending_app/features/product_master/domain/value_objects/master_id.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';

void main() {
  testWidgets('メーカー簡単登録の内容を確認できる', (WidgetTester tester) async {
    final manufacturer = _manufacturer();
    final container = ProviderContainer(
      overrides: [
        manufacturerRepositoryProvider.overrideWithValue(
          _FakeManufacturerRepository(<Manufacturer>[manufacturer]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final registration = container.read(
      machineRegistrationControllerProvider.notifier,
    );
    registration.setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    registration.continueFromPosition();
    registration.continueAfterDuplicateCheck();
    registration.chooseManufacturerMethod();

    await container
        .read(manufacturerSelectionControllerProvider.notifier)
        .load();

    registration.selectManufacturer(manufacturer.id);

    var submitCount = 0;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2RegistrationConfirmationScreen(
            onSubmit: () async {
              submitCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('コカ・コーラ'), findsOneWidget);
    expect(find.textContaining('代表商品 1件'), findsOneWidget);
    expect(find.text('登録時に自動設定'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('registrationConfirmationSubmitButton')),
      300,
    );

    await tester.tap(
      find.byKey(const Key('registrationConfirmationSubmitButton')),
    );
    await tester.pump();

    expect(submitCount, 1);
  });

  testWidgets('メーカー不明は位置のみ登録として表示する', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        manufacturerRepositoryProvider.overrideWithValue(
          const _FakeManufacturerRepository(<Manufacturer>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final registration = container.read(
      machineRegistrationControllerProvider.notifier,
    );
    registration.setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    registration.continueFromPosition();
    registration.continueAfterDuplicateCheck();
    registration.chooseLocationOnly();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: V2RegistrationConfirmationScreen()),
      ),
    );

    expect(find.text('分からない'), findsOneWidget);
    expect(find.text('商品情報なし'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('registrationConfirmationSubmitButton')),
      300,
    );

    expect(find.text('保存処理を準備中'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('registrationConfirmationSubmitButton')),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('photo登録では確認済み商品を表示しメーカー推定文言を出さない', (WidgetTester tester) async {
    final manufacturer = _asahiManufacturer();

    final container = ProviderContainer(
      overrides: [
        manufacturerRepositoryProvider.overrideWithValue(
          _FakeManufacturerRepository(<Manufacturer>[manufacturer]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final registration = container.read(
      machineRegistrationControllerProvider.notifier,
    );

    registration.setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    registration.continueFromPosition();
    registration.continueAfterDuplicateCheck();
    registration.choosePhotoMethod();
    registration.setTemporaryPhotoUploadId(
      '123e4567-e89b-42d3-a456-426614174001',
    );

    await container
        .read(manufacturerSelectionControllerProvider.notifier)
        .load();

    registration.applyPhotoRecognitionConfirmation(
      manufacturerId: manufacturer.id,
      productIds: <ProductId>[
        ProductId.parse('asahi_wonda_black'),
        ProductId.parse('asahi_calpis_water'),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: V2RegistrationConfirmationScreen()),
      ),
    );

    expect(find.text('写真から確認したメーカー・商品を登録します。'), findsOneWidget);
    expect(find.text('アサヒ'), findsOneWidget);
    expect(find.text('確認済み商品 2件'), findsOneWidget);
    expect(find.textContaining('確認して選んだ商品だけを登録'), findsOneWidget);
    expect(find.textContaining('代表商品'), findsNothing);
    expect(find.textContaining('「あるかも」として登録'), findsNothing);
  });
}

Manufacturer _manufacturer() {
  return Manufacturer(
    id: ManufacturerId.parse('coca_cola'),
    name: 'コカ・コーラ',
    displayShortName: 'コカ・コーラ',
    presetProductIds: <ProductId>[ProductId.parse('ayataka_regular')],
    createdAt: DateTime.utc(2026, 8, 11),
    updatedAt: DateTime.utc(2026, 8, 11),
  );
}

Manufacturer _asahiManufacturer() {
  return Manufacturer(
    id: ManufacturerId.parse('asahi'),
    name: 'アサヒ飲料',
    displayShortName: 'アサヒ',
    presetProductIds: <ProductId>[ProductId.parse('asahi_wonda_black')],
    createdAt: DateTime.utc(2026, 8, 11),
    updatedAt: DateTime.utc(2026, 8, 11),
  );
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
