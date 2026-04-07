import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FavoriteDrinkService {
  FavoriteDrinkService._();

  static const String _storageKey = 'favorite_drinks_v1';

  static String _normalize(String input) {
    return input.trim().toLowerCase();
  }

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return <String>[];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return <String>[];
      }

      final normalized = decoded
          .map((e) => _normalize(e.toString()))
          .where((e) => e.isNotEmpty)
          .cast<String>()
          .toList();

      return _unique(normalized);
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> save(List<String> drinks) async {
    final prefs = await SharedPreferences.getInstance();

    final normalized = drinks
        .map(_normalize)
        .where((e) => e.isNotEmpty)
        .toList();

    final unique = _unique(normalized);

    await prefs.setString(_storageKey, jsonEncode(unique));
  }

  static Future<void> toggle(String drinkName) async {
    final normalized = _normalize(drinkName);
    if (normalized.isEmpty) return;

    final current = await load();
    final list = List<String>.from(current);

    if (list.contains(normalized)) {
      list.remove(normalized);
    } else {
      list.insert(0, normalized);
    }

    await save(list);
  }

  static Future<bool> isFavorite(String drinkName) async {
    final normalized = _normalize(drinkName);
    if (normalized.isEmpty) return false;

    final current = await load();
    return current.contains(normalized);
  }

  static Future<void> remove(String drinkName) async {
    final normalized = _normalize(drinkName);
    if (normalized.isEmpty) return;

    final current = await load();
    final list = List<String>.from(current)..remove(normalized);
    await save(list);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  static List<String> _unique(List<String> source) {
    final result = <String>[];
    final seen = <String>{};

    for (final item in source) {
      if (seen.contains(item)) continue;
      seen.add(item);
      result.add(item);
    }

    return result;
  }
}