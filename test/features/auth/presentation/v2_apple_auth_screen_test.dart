import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/apple_auth_providers.dart';
import 'package:vending_app/features/auth/domain/repositories/apple_auth_repository.dart';
import 'package:vending_app/features/auth/presentation/v2_email_auth_screen.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    _Repository repository, {
    bool available = true,
    VoidCallback? authenticated,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        appleSignInAvailableProvider.overrideWithValue(available),
        appleAuthRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: V2EmailAuthScreen(onAuthenticated: authenticated),
      ),
    ),
  );

  testWidgets(
    'Android/default unsupported platform keeps Apple button hidden',
    (tester) async {
      await pump(tester, _Repository(), available: false);
      expect(find.byKey(const Key('appleAuthButton')), findsNothing);
    },
  );
  testWidgets(
    'success returns to caller; hidden email does not need a form value',
    (tester) async {
      var returned = 0;
      await pump(tester, _Repository(), authenticated: () => returned++);
      await tester.scrollUntilVisible(
        find.byKey(const Key('appleAuthButton')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('appleAuthButton')));
      await tester.pump();
      expect(returned, 1);
      expect(find.textContaining('メールを非公開'), findsOneWidget);
      expect(find.textContaining('自動で統合されません'), findsOneWidget);
    },
  );
  testWidgets('cancel stays on login screen without error', (tester) async {
    final repository = _Repository()..result = const AppResult.success(false);
    await pump(tester, repository);
    await tester.scrollUntilVisible(
      find.byKey(const Key('appleAuthButton')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('appleAuthButton')));
    await tester.pump();
    expect(find.byKey(const Key('appleAuthFailure')), findsNothing);
    expect(find.byType(V2EmailAuthScreen), findsOneWidget);
  });
  testWidgets('disposing during native sign-in does not call a dead screen', (
    tester,
  ) async {
    final pending = Completer<AppResult<bool>>();
    final repository = _Repository()..pending = pending.future;
    var callbacks = 0;
    await pump(tester, repository, authenticated: () => callbacks++);
    await tester.scrollUntilVisible(
      find.byKey(const Key('appleAuthButton')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('appleAuthButton')));
    await tester.pump();
    expect(repository.calls, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(const AppResult.success(true));
    await tester.pumpAndSettle();
    expect(callbacks, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('errors are visible and repeated taps cannot start two logins', (
    tester,
  ) async {
    final gate = Completer<AppResult<bool>>();
    final repository = _Repository()..pending = gate.future;
    await pump(tester, repository);
    await tester.scrollUntilVisible(
      find.byKey(const Key('appleAuthButton')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('appleAuthButton')));
    await tester.tap(find.byKey(const Key('appleAuthButton')));
    await tester.pump();
    expect(repository.calls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('appleAuthButton')))
          .onPressed,
      isNull,
    );
    gate.complete(const AppResult.failure(NetworkFailure()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('appleAuthFailure')), findsOneWidget);
    expect(find.text('通信状態を確認して、もう一度お試しください。'), findsOneWidget);
  });
}

final class _Repository implements AppleAuthRepository {
  AppResult<bool> result = const AppResult.success(true);
  Future<AppResult<bool>>? pending;
  int calls = 0;
  @override
  Future<AppResult<bool>> signIn() async {
    calls++;
    return await (pending ?? Future.value(result));
  }

  @override
  Future<AppResult<bool>> reauthenticateForDeletion() async =>
      const AppResult.success(false);
  @override
  Future<AppResult<bool>> revokeForDeletion() async =>
      const AppResult.success(false);
  @override
  void discardDeletionAuthorization() {}
}
