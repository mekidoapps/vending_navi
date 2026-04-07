import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/position_data.dart';
import '../models/vending_machine.dart';
import '../utils/distance_util.dart';
import 'notification_settings_service.dart';

class NearbyFavoriteNotificationService {
  NearbyFavoriteNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static final Set<String> _notifiedMachineIds = <String>{};
  static String? _pendingMachineId;

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: android,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.trim().isNotEmpty) {
          _pendingMachineId = payload.trim();
        }
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchPayload != null && launchPayload.trim().isNotEmpty) {
      _pendingMachineId = launchPayload.trim();
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static String? consumePendingMachineId() {
    final id = _pendingMachineId;
    _pendingMachineId = null;
    return id;
  }

  static Future<void> checkAndNotify({
    required PositionData? currentPosition,
    required List<VendingMachine> machines,
    required List<String> favoriteDrinks,
  }) async {
    final settings = await NotificationSettingsService.load();

    if (!settings.enabled) return;
    if (currentPosition == null) return;
    if (favoriteDrinks.isEmpty) return;
    if (machines.isEmpty) return;

    for (final machine in machines) {
      if (machine.id.isEmpty) continue;
      if (_notifiedMachineIds.contains(machine.id)) continue;

      final distance = DistanceUtil.calculateDistanceMeters(
        fromLat: currentPosition.latitude,
        fromLng: currentPosition.longitude,
        toLat: machine.latitude,
        toLng: machine.longitude,
      );

      if (!distance.isFinite || distance > settings.radiusMeters) {
        continue;
      }

      final matchedDrink = _findMatchedFavoriteDrink(
        machine: machine,
        favoriteDrinks: favoriteDrinks,
      );

      if (matchedDrink == null) continue;

      await _showNearbyDrinkNotification(
        machineId: machine.id,
        machineName: machine.name,
        drinkName: matchedDrink,
        distanceMeters: distance,
      );

      _notifiedMachineIds.add(machine.id);
    }
  }

  static String? _findMatchedFavoriteDrink({
    required VendingMachine machine,
    required List<String> favoriteDrinks,
  }) {
    final allProducts = <String>{
      ...machine.drinkSlots
          .map((slot) => (slot['name'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty),
    };

    for (final product in allProducts) {
      final normalizedProduct = _normalize(product);

      for (final favorite in favoriteDrinks) {
        final normalizedFavorite = _normalize(favorite);

        if (normalizedFavorite.isEmpty) continue;

        if (normalizedProduct.contains(normalizedFavorite) ||
            normalizedFavorite.contains(normalizedProduct)) {
          return product;
        }
      }
    }

    return null;
  }

  static Future<void> _showNearbyDrinkNotification({
    required String machineId,
    required String machineName,
    required String drinkName,
    required double distanceMeters,
  }) async {
    final roundedDistance = distanceMeters < 1000
        ? '${distanceMeters.toStringAsFixed(0)}m'
        : '${(distanceMeters / 1000).toStringAsFixed(1)}km';

    const androidDetails = AndroidNotificationDetails(
      'favorite_drink_nearby_channel',
      'お気に入りドリンク通知',
      channelDescription: '近くにお気に入りドリンクがある自販機を通知します',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '近くにお気に入りがあります',
      '$drinkName が $machineName にあります（$roundedDistance）',
      details,
      payload: machineId,
    );
  }

  static String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }

  static void clearNotifiedCache() {
    _notifiedMachineIds.clear();
  }
}