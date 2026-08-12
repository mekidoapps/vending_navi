import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_state.dart';
import 'package:vending_app/features/machine_registration/domain/entities/machine_registration_method.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_method_screen.dart';

void main() {
  testWidgets('Phase 6ではメーカー簡単登録を選択できる', (WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var selected = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: V2RegistrationMethodScreen(
            onManufacturerSelected: () {
              selected = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('写真から登録'), findsWidgets);
    expect(find.text('メーカーから簡単登録'), findsOneWidget);
    expect(find.text('準備中'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('registrationManufacturerMethodButton')),
    );
    await tester.pump();

    final state = container.read(machineRegistrationControllerProvider);
    expect(selected, isTrue);
    expect(state.step, MachineRegistrationStep.manufacturer);
    expect(
      state.draft.registrationMethod,
      MachineRegistrationMethod.manufacturer,
    );
  });

  testWidgets('Phase 7未接続なら写真ボタンは無効', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: V2RegistrationMethodScreen()),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('registrationPhotoMethodButton')),
    );

    expect(button.onPressed, isNull);
    expect(find.text('準備中'), findsOneWidget);
  });
}
