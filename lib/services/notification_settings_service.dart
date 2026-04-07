import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    required this.radiusMeters,
  });

  final bool enabled;
  final double radiusMeters;

  NotificationSettings copyWith({
    bool? enabled,
    double? radiusMeters,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      radiusMeters: radiusMeters ?? this.radiusMeters,
    );
  }
}

class NotificationSettingsService {
  NotificationSettingsService._();

  static const String _enabledKey = 'favorite_notification_enabled';
  static const String _radiusKey = 'favorite_notification_radius_meters';

  static const NotificationSettings _defaultSettings = NotificationSettings(
    enabled: true,
    radiusMeters: 300,
  );

  static Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    final enabled = prefs.getBool(_enabledKey) ?? _defaultSettings.enabled;
    final radius = prefs.getDouble(_radiusKey) ?? _defaultSettings.radiusMeters;

    return NotificationSettings(
      enabled: enabled,
      radiusMeters: radius,
    );
  }

  static Future<NotificationSettings> save({
    required bool enabled,
    required double radiusMeters,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_enabledKey, enabled);
    await prefs.setDouble(_radiusKey, radiusMeters);

    return NotificationSettings(
      enabled: enabled,
      radiusMeters: radiusMeters,
    );
  }
}