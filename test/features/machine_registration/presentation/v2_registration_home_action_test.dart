import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vending_app/app/router/app_route.dart';
import 'package:vending_app/features/machine_registration/application/machine_registration_controller.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_home_action.dart';
import 'package:vending_app/features/vending_machine/domain/value_objects/geo_coordinate.dart';

void main() {
  testWidgets('draftなしでは確認せずホームへ戻る', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    await tester.tap(find.byKey(const Key('registrationHomeButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('registrationTestHome')), findsOneWidget);
    expect(
      harness.container.read(machineRegistrationControllerProvider).draft.hasUserInput,
      isFalse,
    );
  });

  testWidgets('draftありで続けると現在の内容を維持する', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    harness.container
        .read(machineRegistrationControllerProvider.notifier)
        .setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    await harness.pump(tester);

    await tester.tap(find.byKey(const Key('registrationHomeButton')));
    await tester.pumpAndSettle();
    expect(find.text('登録を中止してホームへ戻りますか？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('registrationHomeContinueButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('registrationTestStep')), findsOneWidget);
    expect(
      harness.container
          .read(machineRegistrationControllerProvider)
          .draft
          .location
          ?.latitude,
      35.68,
    );
  });

  testWidgets('draftありで中止するとresetしてホームへ戻る', (tester) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    harness.container
        .read(machineRegistrationControllerProvider.notifier)
        .setLocation(GeoCoordinate(latitude: 35.68, longitude: 139.76));
    await harness.pump(tester);

    await tester.tap(find.byKey(const Key('registrationHomeButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registrationHomeDiscardButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('registrationTestHome')), findsOneWidget);
    expect(
      harness.container.read(machineRegistrationControllerProvider).draft.hasUserInput,
      isFalse,
    );
  });

  testWidgets('small viewportでもホーム導線がoverflowしない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = _Harness();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    expect(find.byKey(const Key('registrationHomeButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _Harness {
  _Harness() : container = ProviderContainer() {
    router = GoRouter(
      initialLocation: AppRoute.v2RegistrationPosition.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.v2Foundation.path,
          name: AppRoute.v2Foundation.name,
          builder: (_, _) => const Scaffold(
            body: Center(child: Text('ホーム', key: Key('registrationTestHome'))),
          ),
        ),
        GoRoute(
          path: AppRoute.v2RegistrationPosition.path,
          name: AppRoute.v2RegistrationPosition.name,
          builder: (_, _) => Consumer(
            builder: (context, ref, _) => Scaffold(
              key: const Key('registrationTestStep'),
              appBar: AppBar(
                title: const Text('登録'),
                actions: V2RegistrationHomeAction.appBarActions(context, ref),
              ),
            ),
          ),
        ),
      ],
    );
  }

  final ProviderContainer container;
  late final GoRouter router;

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  void dispose() {
    router.dispose();
    container.dispose();
  }
}
