import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/feedback_category.dart';
import '../models/feedback_submit_result.dart';

class FeedbackService {
  FeedbackService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String appId = 'vending_navi';
  static const String functionName = 'submitFeedback';
  static const String feedbackCollection = 'feedback_items';

  Future<FeedbackSubmitResult> submitFeedback({
    required FeedbackCategory category,
    required String message,
    String? screen,
    String? stepsToReproduce,
    bool replyRequested = false,
    String? locale,
  }) async {
    final trimmedMessage = message.trim();
    final trimmedScreen = (screen ?? '').trim();
    final trimmedSteps = (stepsToReproduce ?? '').trim();

    if (trimmedMessage.length < 10 || trimmedMessage.length > 2000) {
      throw const FeedbackValidationException(
        '内容は10文字以上2000文字以下で入力してください。',
      );
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final payload = <String, dynamic>{
      'appId': appId,
      'category': category.value,
      'message': trimmedMessage,
      'screen': trimmedScreen.isEmpty ? null : trimmedScreen,
      'stepsToReproduce': trimmedSteps.isEmpty ? null : trimmedSteps,
      'replyRequested': replyRequested,
      'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
      'platform': _platformName,
      'locale': locale,
      'clientCreatedAt': DateTime.now().toIso8601String(),
    };

    try {
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call<Map<String, dynamic>>(payload);
      final data = result.data ?? <String, dynamic>{};
      return FeedbackSubmitResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      // MVP公開前後で Cloud Functions が未デプロイの場合、not-found になる。
      // その場合だけ Firestore 直接保存にフォールバックして、アプリ内フォームを止めない。
      if (e.code == 'not-found') {
        return _submitDirectlyToFirestore(payload);
      }
      throw FeedbackSubmitException(_mapFunctionErrorMessage(e));
    } on FirebaseException catch (e) {
      throw FeedbackSubmitException(_mapFirebaseErrorMessage(e));
    } catch (_) {
      throw const FeedbackSubmitException(
        '送信に失敗しました。通信状況を確認して、少し時間をおいて再度お試しください。',
      );
    }
  }

  Future<FeedbackSubmitResult> _submitDirectlyToFirestore(
      Map<String, dynamic> payload,
      ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const FeedbackSubmitException('ログインが必要です。');
    }

    try {
      final docRef = await _firestore.collection(feedbackCollection).add({
        ...payload,
        'uid': user.uid,
        'userDisplayName': user.displayName,
        'userEmail': user.email,
        'status': 'new',
        'priority': 'normal',
        'isSpamSuspected': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return FeedbackSubmitResult.fromMap({
        'success': true,
        'id': docRef.id,
        'message': '送信しました。ありがとうございます。',
      });
    } on FirebaseException catch (e) {
      throw FeedbackSubmitException(_mapFirebaseErrorMessage(e));
    } catch (_) {
      throw const FeedbackSubmitException(
        '送信に失敗しました。通信状況を確認して、少し時間をおいて再度お試しください。',
      );
    }
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  String _mapFunctionErrorMessage(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'ログインが必要です。';
      case 'invalid-argument':
        return e.message ?? '入力内容を確認してください。';
      case 'resource-exhausted':
        return e.message ?? '短時間に送信しすぎています。少し待ってからお試しください。';
      case 'unavailable':
        return '現在送信しづらい状態です。少し時間をおいて再度お試しください。';
      default:
        return e.message ?? '送信に失敗しました。';
    }
  }

  String _mapFirebaseErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return '送信権限がありません。ログイン状態を確認してください。';
      case 'unavailable':
        return '現在送信しづらい状態です。少し時間をおいて再度お試しください。';
      case 'not-found':
        return '送信先が見つかりませんでした。アプリを更新して再度お試しください。';
      default:
        return e.message ?? '送信に失敗しました。';
    }
  }
}

class FeedbackValidationException implements Exception {
  const FeedbackValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FeedbackSubmitException implements Exception {
  const FeedbackSubmitException(this.message);

  final String message;

  @override
  String toString() => message;
}
