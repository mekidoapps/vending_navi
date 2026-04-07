import 'package:shared_preferences/shared_preferences.dart';

class FavoriteService {
  static const _key = 'favorite_machine_ids';

  static Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.toSet();
  }

  static Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];

    final set = list.toSet();

    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }

    await prefs.setStringList(_key, set.toList());
  }

  static Future<bool> isFavorite(String id) async {
    final set = await loadFavorites();
    return set.contains(id);
  }
}