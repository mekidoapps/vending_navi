import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_progress.dart';

class LocalProgressService {
  LocalProgressService._();

  static const String _storageKey = 'app_progress_v1';

  static Future<AppProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return AppProgress.initial();
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        return AppProgress.fromJson(decoded);
      }

      if (decoded is Map) {
        return AppProgress.fromJson(
          decoded.map(
                (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }

      return AppProgress.initial();
    } catch (_) {
      return AppProgress.initial();
    }
  }

  static Future<void> save(AppProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(progress.toJson()),
    );
  }

  static Future<AppProgress> addSearchHistory(String keyword) async {
    final progress = await load();

    final updated = progress.copyWith(
      searchHistory: _pushRecent(
        progress.searchHistory,
        keyword,
        limit: 12,
      ),
    );

    await save(updated);
    return updated;
  }

  static Future<AppProgress> clearSearchHistory() async {
    final progress = await load();

    final updated = progress.copyWith(
      searchHistory: <String>[],
    );

    await save(updated);
    return updated;
  }

  static Future<AppProgress> addViewedMachine({
    required String machineId,
    required String machineName,
  }) async {
    final progress = await load();

    final updated = progress.copyWith(
      viewedMachineNames: _pushRecent(
        progress.viewedMachineNames,
        machineName,
        limit: 12,
      ),
    );

    await save(updated);
    return updated;
  }

  static Future<AppProgress> addCreatedMachine(String machineName) async {
    final progress = await load();

    const gainedExp = 10;
    final newExp = progress.exp + gainedExp;
    final newLevel = (newExp ~/ 100) + 1;

    final updated = progress.copyWith(
      exp: newExp,
      level: newLevel,
      createdMachineNames: _pushRecent(
        progress.createdMachineNames,
        machineName,
        limit: 20,
      ),
    );

    await save(updated);
    return updated;
  }

  static List<String> _pushRecent(
      List<String> source,
      String value, {
        required int limit,
      }) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return List<String>.from(source);
    }

    final list = List<String>.from(source)
      ..removeWhere((e) => e.trim() == normalized)
      ..insert(0, normalized);

    if (list.length > limit) {
      return list.take(limit).toList();
    }

    return list;
  }
}