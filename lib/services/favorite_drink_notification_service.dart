import '../models/favorite_drink_notification.dart';

class FavoriteDrinkNotificationService {
  FavoriteDrinkNotificationService._internal();

  static final FavoriteDrinkNotificationService _instance =
  FavoriteDrinkNotificationService._internal();

  factory FavoriteDrinkNotificationService() => _instance;

  final List<FavoriteDrinkNotification> _cache =
  <FavoriteDrinkNotification>[];

  List<FavoriteDrinkNotification> get cachedNotifications =>
      List<FavoriteDrinkNotification>.unmodifiable(_cache);

  void setNotifications(List<FavoriteDrinkNotification> items) {
    _cache
      ..clear()
      ..addAll(items);
  }

  void addNotification(FavoriteDrinkNotification item) {
    _cache.insert(0, item);
  }

  void markAsRead(String id) {
    final int index = _cache.indexWhere(
          (FavoriteDrinkNotification e) => e.id == id,
    );

    if (index == -1) return;

    final FavoriteDrinkNotification old = _cache[index];
    _cache[index] = old.copyWith(isRead: true);
  }

  void clear() {
    _cache.clear();
  }
}