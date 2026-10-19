import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/auth/application/providers/auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:vending_app/features/machine_registration/application/providers/machine_registration_providers.dart';
import 'package:vending_app/features/machine_registration/domain/models/normalized_registration_photo.dart';
import 'package:vending_app/features/machine_registration/domain/models/temporary_registration_photo_upload.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_photo_capture_source.dart';
import 'package:vending_app/features/machine_registration/domain/services/registration_photo_normalizer.dart';
import 'package:vending_app/features/machine_registration/domain/services/temporary_registration_photo_uploader.dart';
import 'package:vending_app/features/machine_registration/presentation/v2_registration_photo_screen.dart';

void main() {
  for (final dismissal in ['cancel', 'back', 'barrier']) {
    testWidgets('$dismissal sends nothing and next attempt requires consent', (
      tester,
    ) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      await fixture.openConsent(tester);
      expect(find.textContaining('Firebase Storage'), findsOneWidget);
      expect(find.textContaining('Vertex AI'), findsOneWidget);
      expect(fixture.source.calls, 0);
      expect(fixture.uploader.calls, 0);
      switch (dismissal) {
        case 'cancel':
          await tester.tap(
            find.byKey(const Key('registrationPhotoConsentCancel')),
          );
        case 'back':
          await tester.binding.handlePopRoute();
        case 'barrier':
          await tester.tapAt(const Offset(5, 5));
      }
      await tester.pumpAndSettle();
      expect(fixture.source.calls, 0);
      expect(fixture.uploader.calls, 0);
      expect(fixture.prepared, 0);
      await fixture.openConsent(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fixture.source.calls, 0);
      await tester.tap(find.byKey(const Key('registrationPhotoConsentAgree')));
      await tester.pumpAndSettle();
      expect(fixture.source.calls, 1);
      expect(fixture.uploader.calls, 1);
      expect(fixture.prepared, 1);
      await fixture.openConsent(tester);
      expect(fixture.uploader.calls, 1);
      await tester.tap(find.byKey(const Key('registrationPhotoConsentCancel')));
      await tester.pumpAndSettle();
      expect(fixture.uploader.calls, 1);
    });
  }

  testWidgets('rapid taps open one dialog and upload only once', (
    tester,
  ) async {
    final fixture = _Fixture();
    fixture.source.pending = Completer<Uint8List?>();
    await fixture.mount(tester);
    final capture = find.byKey(const Key('registrationPhotoCaptureButton'));
    await tester.ensureVisible(capture);
    // Simulate two callbacks queued before the disabled state is rebuilt.
    final captureAction = tester.widget<FilledButton>(capture).onPressed!;
    captureAction();
    captureAction();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final agree = find.byKey(const Key('registrationPhotoConsentAgree'));
    final agreeAction = tester.widget<FilledButton>(agree).onPressed!;
    agreeAction();
    agreeAction();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(fixture.source.calls, 1);
    expect(fixture.uploader.calls, 0);
    expect(tester.widget<FilledButton>(capture).onPressed, isNull);
    fixture.source.pending!.complete(_bytes);
    await tester.pumpAndSettle();
    expect(fixture.uploader.calls, 1);
    expect(fixture.prepared, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera cancellation sends nothing and retry asks again', (
    tester,
  ) async {
    final fixture = _Fixture();
    fixture.source.cancel = true;
    await fixture.mount(tester);
    await fixture.openConsent(tester);
    await tester.tap(find.byKey(const Key('registrationPhotoConsentAgree')));
    await tester.pumpAndSettle();
    expect(fixture.source.calls, 1);
    expect(fixture.uploader.calls, 0);
    expect(fixture.prepared, 0);
    await fixture.openConsent(tester);
    expect(fixture.source.calls, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });

  testWidgets('leaving the photo route while consent is open sends nothing', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.mount(tester);
    await fixture.openConsent(tester);
    fixture.navigator.currentState!.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(fixture.source.calls, 0);
    expect(fixture.uploader.calls, 0);
    expect(fixture.prepared, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consent remains usable on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final fixture = _Fixture();
    await fixture.mount(tester);
    await fixture.openConsent(tester);
    await tester.ensureVisible(
      find.byKey(const Key('registrationPhotoConsentCancel')),
    );
    await tester.tap(find.byKey(const Key('registrationPhotoConsentCancel')));
    await tester.pumpAndSettle();
    expect(fixture.uploader.calls, 0);
    expect(tester.takeException(), isNull);
  });

  for (final stage in ['capture', 'normalize']) {
    testWidgets('leaving during $stage prevents later upload', (tester) async {
      final fixture = _Fixture();
      if (stage == 'capture') {
        fixture.source.pending = Completer<Uint8List?>();
      } else {
        fixture.normalizer.pending = Completer<NormalizedRegistrationPhoto>();
      }
      await fixture.mount(tester);
      await fixture.openConsent(tester);
      await tester.tap(find.byKey(const Key('registrationPhotoConsentAgree')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(fixture.source.calls, 1);
      fixture.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      if (stage == 'capture') {
        fixture.source.pending!.complete(_bytes);
      } else {
        fixture.normalizer.pending!.complete(
          NormalizedRegistrationPhoto(bytes: _bytes, width: 1, height: 1),
        );
      }
      await tester.pumpAndSettle();
      expect(fixture.uploader.calls, 0);
      expect(fixture.prepared, 0);
      expect(tester.takeException(), isNull);
    });
  }
}

final _bytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
    'AgUBAO+X2ioAAAAASUVORK5CYII=',
  ),
);

class _Fixture {
  final source = _Source();
  final normalizer = _Normalizer();
  final uploader = _Uploader();
  final navigator = GlobalKey<NavigatorState>();
  int prepared = 0;

  Future<void> mount(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_Auth()),
        registrationPhotoCaptureSourceProvider.overrideWithValue(source),
        registrationPhotoNormalizerProvider.overrideWithValue(normalizer),
        temporaryRegistrationPhotoUploaderProvider.overrideWithValue(uploader),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              V2RegistrationPhotoScreen(onPhotoPrepared: () => prepared++),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openConsent(WidgetTester tester) async {
    final button = find.byKey(const Key('registrationPhotoCaptureButton'));
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

class _Auth extends Fake implements AuthRepository {
  final session = AuthenticatedAuthSession(
    AuthUser(
      uid: 'consent-test',
      email: null,
      displayName: null,
      providerIds: const ['password'],
      emailVerified: true,
    ),
  );
  @override
  AuthSession get currentSession => session;
  @override
  Stream<AuthSession> watchSession() => Stream.value(session);
}

class _Source implements RegistrationPhotoCaptureSource {
  int calls = 0;
  bool cancel = false;
  Completer<Uint8List?>? pending;
  @override
  Future<Uint8List?> capture() async {
    calls++;
    return pending != null ? pending!.future : (cancel ? null : _bytes);
  }
}

class _Normalizer implements RegistrationPhotoNormalizer {
  Completer<NormalizedRegistrationPhoto>? pending;
  @override
  Future<NormalizedRegistrationPhoto> normalize(Uint8List bytes) async =>
      pending != null
      ? pending!.future
      : NormalizedRegistrationPhoto(bytes: bytes, width: 1, height: 1);
}

class _Uploader implements TemporaryRegistrationPhotoUploader {
  int calls = 0;
  @override
  Future<TemporaryRegistrationPhotoUpload> upload({
    required String uploadId,
    required Uint8List jpegBytes,
  }) async {
    calls++;
    return TemporaryRegistrationPhotoUpload(
      uploadId: uploadId,
      objectPath: 'fixture/$uploadId',
    );
  }
}
