import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/app/theme/v2_theme.dart';
import 'package:vending_app/core/result/app_result.dart';
import 'package:vending_app/features/auth/application/providers/google_auth_providers.dart';
import 'package:vending_app/features/auth/domain/entities/auth_session.dart';
import 'package:vending_app/features/auth/domain/entities/auth_user.dart';
import 'package:vending_app/features/auth/domain/entities/google_sign_in_outcome.dart';
import 'package:vending_app/features/auth/domain/repositories/google_auth_repository.dart';
import 'package:vending_app/features/auth/presentation/v2_email_auth_screen.dart';

void main() {
  testWidgets('Google buttonを表示する', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleAuthRepositoryProvider.overrideWithValue(
            const _FakeGoogleAuthRepository(
              AppResult<GoogleSignInOutcome>.success(GoogleSignInCancelled()),
            ),
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2EmailAuthScreen(),
        ),
      ),
    );

    expect(find.byKey(const Key('googleAuthButton')), findsOneWidget);
    expect(find.text('Googleで続ける'), findsOneWidget);
  });

  testWidgets('Google successでcallbackへ復帰する', (WidgetTester tester) async {
    var authenticated = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleAuthRepositoryProvider.overrideWithValue(
            _FakeGoogleAuthRepository(
              AppResult<GoogleSignInOutcome>.success(
                GoogleSignInCompleted(_session()),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: V2EmailAuthScreen(
            onAuthenticated: () {
              authenticated = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('googleAuthButton')));
    await tester.pump();

    expect(authenticated, isTrue);
  });

  testWidgets('Google cancelではerrorを出さず画面に残る', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleAuthRepositoryProvider.overrideWithValue(
            const _FakeGoogleAuthRepository(
              AppResult<GoogleSignInOutcome>.success(GoogleSignInCancelled()),
            ),
          ),
        ],
        child: MaterialApp(
          theme: V2Theme.light(),
          home: const V2EmailAuthScreen(),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('googleAuthButton')));
    await tester.pump();

    expect(find.byKey(const Key('googleAuthFailure')), findsNothing);
    expect(find.byKey(const Key('googleAuthButton')), findsOneWidget);
  });
}

AuthSession _session() {
  return AuthenticatedAuthSession(
    AuthUser(
      uid: 'google_screen_user',
      email: 'google@example.com',
      displayName: 'Google User',
      providerIds: const <String>['google.com'],
      emailVerified: true,
    ),
  );
}

final class _FakeGoogleAuthRepository implements GoogleAuthRepository {
  const _FakeGoogleAuthRepository(this.result);

  final AppResult<GoogleSignInOutcome> result;

  @override
  Future<AppResult<bool>> reauthenticate() async {
    return const AppResult<bool>.success(true);
  }

  @override
  Future<AppResult<GoogleSignInOutcome>> signIn() async {
    return result;
  }
}
