import 'package:cloud_firestore/cloud_firestore.dart';

class UserProgressService {
  UserProgressService._();

  static final UserProgressService instance = UserProgressService._();

  static const int expPerCheckin = 10;
  static const int expPerMachineRegister = 50;
  static const int expPerDrinkRegister = 5;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<void> applyMachineRegisterProgress({
    required String uid,
    required String displayName,
    required int addedDrinkCount,
  }) async {
    if (uid.trim().isEmpty) return;

    final gainedExp =
        expPerMachineRegister + (addedDrinkCount * expPerDrinkRegister);

    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};

      final currentExp = _readInt(data['exp']);
      final currentLevel = _readInt(data['level']).clamp(1, 9999);
      final currentMachineCount = _readInt(data['registeredMachineCount']);
      final currentDrinkCount = _readInt(data['registeredDrinkCount']);
      final currentCheckinCount = _readInt(data['checkinCount']);

      final nextExp = currentExp + gainedExp;
      final nextLevel = calculateLevel(nextExp);

      final currentTitles = _readStringList(data['titles']);
      final nextMachineCount = currentMachineCount + 1;
      final nextDrinkCount = currentDrinkCount + addedDrinkCount;

      final nextTitles = _mergeTitles(
        currentTitles,
        _resolveEarnedTitles(
          machineCount: nextMachineCount,
          drinkCount: nextDrinkCount,
          checkinCount: currentCheckinCount,
        ),
      );

      final currentTitle =
      _resolveCurrentTitle(currentTitles: nextTitles, fallback: 'はじめての登録者');

      tx.set(
        ref,
        <String, dynamic>{
          'displayName': displayName.trim().isEmpty ? 'ユーザー' : displayName.trim(),
          'exp': nextExp,
          'level': nextLevel > 0 ? nextLevel : currentLevel,
          'registeredMachineCount': nextMachineCount,
          'registeredDrinkCount': nextDrinkCount,
          'checkinCount': currentCheckinCount,
          'titles': nextTitles,
          'currentTitle': currentTitle,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> applyCheckinProgress({
    required String uid,
    required String displayName,
  }) async {
    if (uid.trim().isEmpty) return;

    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};

      final currentExp = _readInt(data['exp']);
      final currentMachineCount = _readInt(data['registeredMachineCount']);
      final currentDrinkCount = _readInt(data['registeredDrinkCount']);
      final currentCheckinCount = _readInt(data['checkinCount']);

      final nextExp = currentExp + expPerCheckin;
      final nextLevel = calculateLevel(nextExp);
      final nextCheckinCount = currentCheckinCount + 1;

      final currentTitles = _readStringList(data['titles']);
      final nextTitles = _mergeTitles(
        currentTitles,
        _resolveEarnedTitles(
          machineCount: currentMachineCount,
          drinkCount: currentDrinkCount,
          checkinCount: nextCheckinCount,
        ),
      );

      final currentTitle =
      _resolveCurrentTitle(currentTitles: nextTitles, fallback: 'はじめてのチェックイン');

      tx.set(
        ref,
        <String, dynamic>{
          'displayName': displayName.trim().isEmpty ? 'ユーザー' : displayName.trim(),
          'exp': nextExp,
          'level': nextLevel,
          'registeredMachineCount': currentMachineCount,
          'registeredDrinkCount': currentDrinkCount,
          'checkinCount': nextCheckinCount,
          'titles': nextTitles,
          'currentTitle': currentTitle,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> applyDrinkRegisterProgress({
    required String uid,
    required String displayName,
    required int addedDrinkCount,
  }) async {
    if (uid.trim().isEmpty) return;
    if (addedDrinkCount <= 0) return;

    await _db.runTransaction((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};

      final currentExp = _readInt(data['exp']);
      final currentMachineCount = _readInt(data['registeredMachineCount']);
      final currentDrinkCount = _readInt(data['registeredDrinkCount']);
      final currentCheckinCount = _readInt(data['checkinCount']);

      final nextExp = currentExp + (addedDrinkCount * expPerDrinkRegister);
      final nextLevel = calculateLevel(nextExp);
      final nextDrinkCount = currentDrinkCount + addedDrinkCount;

      final currentTitles = _readStringList(data['titles']);
      final nextTitles = _mergeTitles(
        currentTitles,
        _resolveEarnedTitles(
          machineCount: currentMachineCount,
          drinkCount: nextDrinkCount,
          checkinCount: currentCheckinCount,
        ),
      );

      final currentTitle =
      _resolveCurrentTitle(currentTitles: nextTitles, fallback: 'ドリンク登録ビギナー');

      tx.set(
        ref,
        <String, dynamic>{
          'displayName': displayName.trim().isEmpty ? 'ユーザー' : displayName.trim(),
          'exp': nextExp,
          'level': nextLevel,
          'registeredMachineCount': currentMachineCount,
          'registeredDrinkCount': nextDrinkCount,
          'checkinCount': currentCheckinCount,
          'titles': nextTitles,
          'currentTitle': currentTitle,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<UserProgressSnapshot> getProgress({
    required String uid,
  }) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data() ?? <String, dynamic>{};

    final exp = _readInt(data['exp']);
    final level = _readInt(data['level']);
    final titles = _readStringList(data['titles']);

    return UserProgressSnapshot(
      exp: exp,
      level: level > 0 ? level : calculateLevel(exp),
      currentTitle: _readNullableString(data['currentTitle']) ?? 'はじめの一歩',
      titles: titles,
      registeredMachineCount: _readInt(data['registeredMachineCount']),
      registeredDrinkCount: _readInt(data['registeredDrinkCount']),
      checkinCount: _readInt(data['checkinCount']),
    );
  }

  int calculateLevel(int exp) {
    if (exp <= 0) return 1;

    // 軽めの累積
    // Lv1: 0
    // Lv2: 100
    // Lv3: 250
    // Lv4: 450 ...
    var level = 1;
    var threshold = 100;
    var total = 0;

    while (exp >= total + threshold) {
      total += threshold;
      level += 1;
      threshold += 50;
      if (level >= 9999) break;
    }

    return level;
  }

  int expToNextLevel(int exp) {
    if (exp < 0) return 100;

    var level = 1;
    var threshold = 100;
    var total = 0;

    while (exp >= total + threshold) {
      total += threshold;
      level += 1;
      threshold += 50;
      if (level >= 9999) return 0;
    }

    return (total + threshold) - exp;
  }

  double levelProgressRate(int exp) {
    if (exp < 0) return 0;

    var threshold = 100;
    var total = 0;

    while (exp >= total + threshold) {
      total += threshold;
      threshold += 50;
    }

    final currentInLevel = exp - total;
    if (threshold <= 0) return 0;

    return (currentInLevel / threshold).clamp(0.0, 1.0);
  }

  List<String> _resolveEarnedTitles({
    required int machineCount,
    required int drinkCount,
    required int checkinCount,
  }) {
    final titles = <String>[];

    if (machineCount >= 1) titles.add('はじめての登録者');
    if (machineCount >= 10) titles.add('街角ハンター');
    if (machineCount >= 30) titles.add('自販機ウォッチャー');

    if (drinkCount >= 1) titles.add('ドリンク登録ビギナー');
    if (drinkCount >= 25) titles.add('ラインナップ収集家');
    if (drinkCount >= 100) titles.add('品揃えマスター');

    if (checkinCount >= 1) titles.add('はじめてのチェックイン');
    if (checkinCount >= 10) titles.add('近くの一杯探し');
    if (checkinCount >= 50) titles.add('飲みたいを追う者');

    return titles;
  }

  List<String> _mergeTitles(
      List<String> current,
      List<String> added,
      ) {
    final result = <String>[];
    final used = <String>{};

    for (final title in [...current, ...added]) {
      final trimmed = title.trim();
      if (trimmed.isEmpty) continue;
      if (used.contains(trimmed)) continue;
      used.add(trimmed);
      result.add(trimmed);
    }

    return result;
  }

  String _resolveCurrentTitle({
    required List<String> currentTitles,
    required String fallback,
  }) {
    if (currentTitles.isEmpty) return fallback;
    return currentTitles.last;
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];

    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class UserProgressSnapshot {
  const UserProgressSnapshot({
    required this.exp,
    required this.level,
    required this.currentTitle,
    required this.titles,
    required this.registeredMachineCount,
    required this.registeredDrinkCount,
    required this.checkinCount,
  });

  final int exp;
  final int level;
  final String currentTitle;
  final List<String> titles;
  final int registeredMachineCount;
  final int registeredDrinkCount;
  final int checkinCount;
}