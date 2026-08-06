import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/core/errors/app_failure.dart';
import 'package:vending_app/core/errors/failure_mapper.dart';

void main() {
  group('FailureMapper', () {
    test('AppFailureは変換せずそのまま返す', () {
      const failure = PermissionFailure();

      expect(FailureMapper.map(failure), same(failure));
    });

    test('Firebaseのpermission-deniedをPermissionFailureへ変換する', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(FailureMapper.map(error), isA<PermissionFailure>());
    });

    test('FirebaseのunavailableをNetworkFailureへ変換する', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      expect(FailureMapper.map(error), isA<NetworkFailure>());
    });

    test('PlatformExceptionのtoo_many_requestsをRateLimitFailureへ変換する', () {
      final error = PlatformException(code: 'too_many_requests');

      expect(FailureMapper.map(error), isA<RateLimitFailure>());
    });

    test('TimeoutExceptionをNetworkFailureへ変換する', () {
      final error = TimeoutException('timeout');

      expect(FailureMapper.map(error), isA<NetworkFailure>());
    });

    test('未知のFirebaseコードはコードを保持したFirebaseFailureへ変換する', () {
      final error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'custom-problem',
      );

      final failure = FailureMapper.map(error);

      expect(failure, isA<FirebaseFailure>());
      expect(failure.code, 'firebase.cloud_firestore.custom-problem');
    });

    test('未知の例外をUnknownFailureへ変換する', () {
      expect(
        FailureMapper.map(StateError('unexpected')),
        isA<UnknownFailure>(),
      );
    });
  });
}
