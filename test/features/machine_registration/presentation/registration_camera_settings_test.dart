import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/machine_registration/application/registration_photo_controller.dart';
import 'package:vending_app/features/machine_registration/application/providers/machine_registration_providers.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_photo_capture_source.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_photo_exception.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_photo_screen.dart';

void main() {
  for (final opened in [true, false]) {
    testWidgets(
      'denial offers settings; opened=$opened never starts capture automatically',
      (tester) async {
        var settingsCalls = 0;
        final source = _DeniedSource(
          RegistrationPhotoErrorCode.cameraPermissionDenied,
        );
        final container = ProviderContainer(
          overrides: [
            registrationPhotoCaptureSourceProvider.overrideWithValue(source),
            registrationCameraSettingsProvider.overrideWithValue(() async {
              settingsCalls++;
              return opened;
            }),
          ],
        );
        addTearDown(container.dispose);
        await container
            .read(registrationPhotoControllerProvider.notifier)
            .captureNormalizeAndUpload();
        expect(
          container.read(registrationPhotoControllerProvider).failureCode,
          RegistrationPhotoErrorCode.cameraPermissionDenied,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: V2RegistrationPhotoScreen()),
          ),
        );
        await tester.ensureVisible(
          find.byKey(const Key('registrationCameraSettingsButton')),
        );
        await tester.tap(
          find.byKey(const Key('registrationCameraSettingsButton')),
        );
        await tester.pumpAndSettle();
        expect(settingsCalls, 1);
        expect(source.captureCalls, 1);
        expect(
          find.byKey(const Key('registrationPhotoCaptureButton')),
          findsOneWidget,
        );
        expect(
          find.textContaining('設定を開けませんでした'),
          opened ? findsNothing : findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'restricted camera is not reported as a permission the user can grant',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          registrationPhotoCaptureSourceProvider.overrideWithValue(
            _DeniedSource(RegistrationPhotoErrorCode.cameraRestricted),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(registrationPhotoControllerProvider.notifier)
          .captureNormalizeAndUpload();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: V2RegistrationPhotoScreen()),
        ),
      );
      expect(
        find.byKey(const Key('registrationCameraSettingsButton')),
        findsNothing,
      );
    },
  );
}

final class _DeniedSource implements RegistrationPhotoCaptureSource {
  _DeniedSource(this.code);
  final RegistrationPhotoErrorCode code;
  int captureCalls = 0;
  @override
  Future<Uint8List?> capture() async {
    captureCalls++;
    throw RegistrationPhotoException(
      code: code,
      userMessage: 'Camera permission fixture',
    );
  }
}
