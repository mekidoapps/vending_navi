enum AppEntryMode {
  legacy,
  v2;

  static AppEntryMode fromEnvironment() {
    const value = String.fromEnvironment('APP_ENTRY', defaultValue: 'legacy');
    return fromValue(value);
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
