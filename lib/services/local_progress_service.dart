import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_progress.dart';

class LocalProgressService {
  LocalProgressService._();

  static const String _expKey = 'app_progress_exp';
  static const String _levelKey = 'app_progress_level';
  static const String _searchHistoryKey = 'app_progress_search_history';
  static const String _viewedMachineIdsKey = 'app_progress_viewed_machine_ids';
  static const String _viewedMachineNamesKey =
      'app_progress_viewed_machine_names';
  static const String _createdMachineNamesKey =
      'app_progress_created_machine_names';

  static Future<AppProgress> load() async {
    final prefs = await SharedPreferences.getInstance();

    final exp = prefs.getInt(_expKey) ?? 0;
    final savedLevel = prefs.getInt(_levelKey) ?? 1;
    final recalculatedLevel = AppProgress.levelFromExp(exp);

    final level = recalculatedLevel > savedLevel ? recalculatedLevel : savedLevel;

    return AppProgress(
      exp: exp,
      level: level,
      searchHistory: prefs.getStringList(_searchHistoryKey) ?? <String>[],
      viewedMachineIds: prefs.getStringList(_viewedMachineIdsKey) ?? <String>[],
      viewedMachineNames:
      prefs.getStringList(_viewedMachineNamesKey) ?? <String>[],
      createdMachineNames:
      prefs.getStringList(_createdMachineNamesKey) ?? <String>[],
    );
  }

  static Future<void> save(AppProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_expKey, progress.exp);
    await prefs.setInt(_levelKey, progress.level);
    await prefs.setStringList(_searchHistoryKey, progress.searchHistory);
    await prefs.setStringList(_viewedMachineIdsKey, progress.viewedMachineIds);
    await prefs.setStringList(
      _viewedMachineNamesKey,
      progress.viewedMachineNames,
    );
    await prefs.setStringList(
      _createdMachineNamesKey,
      progress.createdMachineNames,
    );
  }

  static Future<AppProgress> addExp(int amount) async {
    final current = await load();
    final nextExp = current.exp + amount;
    final nextLevel = AppProgress.levelFromExp(nextExp);
    final updated = current.copyWith(
      exp: nextExp,
      level: nextLevel,
    );
    await save(updated);
    return updated;
  }

  static Future<AppProgress> addSearchHistory(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return load();
    }

    final current = await load();
    final next = <String>[...current.searchHistory];
    next.remove(normalized);
    next.insert(0, normalized);

    if (next.length > 8) {
      next.removeRange(8, next.length);
    }

    final updated = current.copyWith(searchHistory: next);
    await save(updated);
    return updated;
  }

  static Future<AppProgress> addViewedMachine({
    required String machineId,
    required String machineName,
  }) async {
    final current = await load();

    final ids = <String>[...current.viewedMachineIds];
    final names = <String>[...current.viewedMachineNames];

    final existingIndex = ids.indexOf(machineId);
    if (existingIndex >= 0) {
      ids.removeAt(existingIndex);
      if (existingIndex < names.length) {
        names.removeAt(existingIndex);
      }
    }

    ids.insert(0, machineId);
    names.insert(0, machineName);

    if (ids.length > 10) {
      ids.removeRange(10, ids.length);
    }
    if (names.length > 10) {
      names.removeRange(10, names.length);
    }

    final updated = current.copyWith(
      viewedMachineIds: ids,
      viewedMachineNames: names,
    );
    await save(updated);
    return updated;
  }

  static Future<AppProgress> addCreatedMachine(String machineName) async {
    final normalized = machineName.trim().isEmpty ? '新しい自販機' : machineName.trim();

    final current = await load();
    final next = <String>[...current.createdMachineNames];
    next.insert(0, normalized);

    if (next.length > 10) {
      next.removeRange(10, next.length);
    }

    final updated = current.copyWith(createdMachineNames: next);
    await save(updated);
    return updated;
  }

  static Future<AppProgress> clearSearchHistory() async {
    final current = await load();
    final updated = current.copyWith(searchHistory: <String>[]);
    await save(updated);
    return updated;
  }
}