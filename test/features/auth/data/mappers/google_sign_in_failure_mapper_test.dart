import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/features/auth/data/mappers/google_sign_in_failure_mapper.dart';

void main() {
  test('cancel codeをcancelとして判定する', () {
    expect(
      GoogleSignInFailureMapper.isCancellationCode('sign_in_canceled'),
      isTrue,
    );
  });

  test('network errorをNetworkFailureへ変換する', () {
    final failure = GoogleSignInFailureMapper.fromPlatformException(
      PlatformException(code: 'network_error'),
    );

    expect(failure, isA<NetworkFailure>());
  });

  test('plugin errorをprivacy-safe failureへ変換する', () {
    final failure = GoogleSignInFailureMapper.fromPlatformException(
      PlatformException(code: 'sign_in_failed'),
    );

    expect(failure, isA<FirebaseFailure>());
    expect(failure.code, contains('google_sign_in'));
  });
}
