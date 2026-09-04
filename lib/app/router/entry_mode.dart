import 'package:flutter/foundation.dart';

enum AppEntryMode {
  legacy,
  v2;

  static AppEntryMode fromEnvironment() {
    const value = String.fromEnvironment('APP_ENTRY', defaultValue: 'legacy');
    return resolve(appEntry: value, isReleaseBuild: kReleaseMode);
  }

  /// Resolves the entry point and rejects a Play release that would otherwise
  /// silently start the legacy application.
  static AppEntryMode resolve({
    required String? appEntry,
    required bool isReleaseBuild,
  }) {
    final entryMode = fromValue(appEntry);
    if (isReleaseBuild && entryMode != AppEntryMode.v2) {
      throw StateError('Release builds require APP_ENTRY=v2.');
    }
    return entryMode;
  }

  static AppEntryMode fromValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'v2':
        return AppEntryMode.v2;
      case 'legacy':
      case 'v1':
      case '':
      case null:
      default:
        return AppEntryMode.legacy;
    }
  }

  String get initialLocation {
    switch (this) {
      case AppEntryMode.legacy:
        return AppRoutePath.legacy;
      case AppEntryMode.v2:
        return AppRoutePath.v2Foundation;
    }
  }
}

abstract final class AppRoutePath {
  static const String legacy = '/';
  static const String v2Foundation = '/v2';
}
