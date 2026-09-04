import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/auth/presentation/auth_diagnostics.dart';

void main() {
  final failure = FirebaseFailure(
    plugin: 'firebase_auth',
    sourceCode: 'operation-not-allowed',
  );

  test('診断OFFでは認証failure codeを表示しない', () {
    const diagnostics = AuthDiagnostics(enabled: false);

    expect(diagnostics.codeForDisplay(failure), isNull);
  });

  test('診断ONでは安全なAppFailure.codeだけを返す', () {
    const diagnostics = AuthDiagnostics(enabled: true);

    expect(
      diagnostics.codeForDisplay(failure),
      'firebase.firebase_auth.operation-not-allowed',
    );
  });
}
