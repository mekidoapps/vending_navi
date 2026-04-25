import 'dart:io' show Platform;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/feedback_category.dart';
import '../models/feedback_submit_result.dart';

class FeedbackService {
  FeedbackService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  static const String appId = 'vending_navi';
  static const String functionName = 'submitFeedback';

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
    final callable = _functions.httpsCallable(functionName);

    try {
      final result = await callable.call<Map<String, dynamic>>({
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
      });

      final data = result.data ?? <String, dynamic>{};
      return FeedbackSubmitResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      throw FeedbackSubmitException(_mapFunctionErrorMessage(e));
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