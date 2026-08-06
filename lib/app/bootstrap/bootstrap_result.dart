import 'package:flutter/foundation.dart';

@immutable
class BootstrapResult {
  const BootstrapResult._({this.errorMessage});

  const BootstrapResult.success() : this._();

  const BootstrapResult.failure(String message) : this._(errorMessage: message);

  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}
