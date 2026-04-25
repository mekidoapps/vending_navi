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

  static const List<TitleRule> titleRules = <TitleRule>[
    TitleRule(
      title: 'はじめの一歩',
      condition: 'ログインしてマイページを見る',
      fallback: true,
    ),
    TitleRule(
      title: '初チェックイン',
      condition: 'チェックインを1回行う',
      minCheckinCount: 1,
    ),
    TitleRule(
      title: '寄り道マスター',
      condition: 'チェックインを10回行う',
      minCheckinCount: 10,
    ),
    TitleRule(
      title: '自販機みつけ隊',
      condition: '自販機を3件登録する',
      minMachineCount: 3,
    ),
    TitleRule(
      title: '自販機ハンター',
      condition: '自販機を10件登録する',
      minMachineCount: 10,
    ),
    TitleRule(
      title: 'ドリンクメモ職人',
      condition: 'ドリンクを10件登録する',
      minDrinkCount: 10,
    ),
    TitleRule(
      title: 'ドリンクコレクター',
      condition: 'ドリンクを30件登録する',
      minDrinkCount: 30,
    ),
    TitleRule(
      title: '自販機ナビ常連',
      condition: 'レベル5に到達する',
      minLevel: 5,
    ),
  ];

  Future<ProgressApplyResult> applyMachineRegisterProgress({
    required String uid,
    required String displayName,
    required int addedDrinkCount,
  }) async {
    if (uid.trim().isEmpty) {
      return ProgressApplyResult.empty();
    }

    final int gainedExp =
        expPerMachineRegister + (addedDrinkCount * expPerDrinkRegister);

    return _db.runTransaction<ProgressApplyResult>((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};

      final int currentExp = _readInt(data['exp']);
      final int currentMachineCount = _readInt(data['registeredMachineCount']);
      final int currentDrinkCount = _readInt(data['registeredDrinkCount']);
      final int currentCheckinCount = _readInt(data['checkinCount']);
      final List<String> currentTitles = _readStringList(data['titles']);

      final int nextExp = currentExp + gainedExp;
      final int nextLevel = calculateLevel(nextExp);
      final int nextMachineCount = currentMachineCount + 1;
      final int nextDrinkCount = currentDrinkCount + addedDrinkCount;

      final List<String> earnedNow = _resolveEarnedTitles(
        level: nextLevel,
        machineCount: nextMachineCount,
        drinkCount: nextDrinkCount,
        checkinCount: currentCheckinCount,
      );

      final List<String> nextTitles = _mergeTitles(currentTitles, earnedNow);
      final List<String> newUnlockedTitles =
      _diffUnlockedTitles(before: currentTitles, after: nextTitles);

      final String currentTitle = _resolveCurrentTitle(
        currentTitles: nextTitles,
        fallback: _fallbackTitle,
      );

      final UserProgressSnapshot snapshot = UserProgressSnapshot(
        exp: nextExp,
        level: nextLevel,
        currentTitle: currentTitle,
        titles: nextTitles,
        registeredMachineCount: nextMachineCount,
        registeredDrinkCount: nextDrinkCount,
        checkinCount: currentCheckinCount,
      );

      tx.set(
        ref,
        <String, dynamic>{
          'displayName': displayName.trim().isEmpty ? 'ユーザー' : displayName.trim(),
          'exp': snapshot.exp,
          'level': snapshot.level,
          'registeredMachineCount': snapshot.registeredMachineCount,
          'registeredDrinkCount': snapshot.registeredDrinkCount,
          'checkinCount': snapshot.checkinCount,
          'titles': snapshot.titles,
          'currentTitle': snapshot.currentTitle,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return ProgressApplyResult(
        snapshot: snapshot,
        earnedTitles: newUnlockedTitles,
      );
    });
  }

  Future<ProgressApplyResult> applyCheckinProgress({
    required String uid,
    required String displayName,
  }) async {
    if (uid.trim().isEmpty) {
      return ProgressApplyResult.empty();
    }

    return _db.runTransaction<ProgressApplyResult>((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};

      final int currentExp = _readInt(data['exp']);
      final int currentMachineCount = _readInt(data['registeredMachineCount']);
      final int currentDrinkCount = _readInt(data['registeredDrinkCount']);
      final int currentCheckinCount = _readInt(data['checkinCount']);
      final List<String> currentTitles = _readStringList(data['titles']);

      final int nextExp = currentExp + expPerCheckin;
      final int nextLevel = calculateLevel(nextExp);
      final int nextCheckinCount = currentCheckinCount + 1;

      final List<String> earnedNow = _resolveEarnedTitles(
        level: nextLevel,
        machineCount: currentMachineCount,
        drinkCount: currentDrinkCount,
        checkinCount: nextCheckinCount,
      );

      final List<String> nextTitles = _mergeTitles(currentTitles, earnedNow);
      final List<String> newUnlockedTitles =
      _diffUnlockedTitles(before: currentTitles, after: nextTitles);

      final String currentTitle = _resolveCurrentTitle(
        currentTitles: nextTitles,
        fallback: _fallbackTitle,
      );

      final UserProgressSnapshot snapshot = UserProgressSnapshot(
        exp: nextExp,
        level: nextLevel,
        currentTitle: currentTitle,
        titles: nextTitles,
        registeredMachineCount: currentMachineCount,
        registeredDrinkCount: currentDrinkCount,
        checkinCount: nextCheckinCount,
      );

      tx.set(
        ref,
        <String, dynamic>{
          'displayName': displayName.trim().isEmpty ? 'ユーザー' : displayName.trim(),
          'exp': snapshot.exp,
          'level': snapshot.level,
          'registeredMachineCount': snapshot.registeredMachineCount,
          'registeredDrinkCount': snapshot.registeredDrinkCount,
          'checkinCount': snapshot.checkinCount,
          'titles': snapshot.titles,
          'currentTitle': snapshot.currentTitle,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return ProgressApplyResult(
        snapshot: snapshot,
        earnedTitles: newUnlockedTitles,
      );
    });
  }

  Future<ProgressApplyResult> applyDrinkRegisterProgress({
    required String uid,
    required String displayName,
    required int addedDrinkCount,
  }) async {
    if (uid.trim().isEmpty || addedDrinkCount <= 0) {
      return ProgressApplyResult.empty();
    }

    return _db.runTransaction<ProgressApplyResult>((tx) async {
      final ref = _users.doc(uid);
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};

      final int currentExp = _readInt(data['exp']);
      final int currentMachineCount = _readInt(data['registeredMachineCount']);
      final int currentDrinkCount = _readInt(data['registeredDrinkCount']);
      final int currentCheckinCount = _readInt(data['checkinCount']);
      final List<String> currentTitles = _readStringList(data['titles']);

      final int nextExp = currentExp + (addedDrinkCount * expPerDrinkRegister);
      final int nextLevel = calculateLevel(nextExp);
      final int nextDrinkCount = currentDrinkCount + addedDrinkCount;

      final List<String> earnedNow = _resolveEarnedTitles(
        level: nextLevel,
        machineCount: currentMachineCount,
        drinkCount: nextDrinkCount,
        checkinCount: currentCheckinCount,
      );

      final List<String> nextTitles = _mergeTitles(currentTitles, earnedNow);
      final List<String> newUnlockedTitles =
      _diffUnlockedTitles(before: currentTitles, after: nextTitles);

      final String currentTitle = _resolveCurrentTitle(
        currentTitles: nextTitles,
        fallback: _fallbackTitle,
      );

      final UserProgressSnapshot snapshot = UserProgressSnapshot(
        exp: nextExp,
        level: nextLevel,
        currentTitle: currentTitle,
        titles: nextTitles,
        registeredMachineCount: currentMachineCount,
        registeredDrinkCount: nextDrinkCount,
        checkinCount: currentCheckinCount,
      );

      tx.set(
        ref,
        <String, dynamic>{
          'displayName': displayName.trim().isEmpty ? 'ユーザー' : displayName.trim(),
          'exp': snapshot.exp,
          'level': snapshot.level,
          'registeredMachineCount': snapshot.registeredMachineCount,
          'registeredDrinkCount': snapshot.registeredDrinkCount,
          'checkinCount': snapshot.checkinCount,
          'titles': snapshot.titles,
          'currentTitle': snapshot.currentTitle,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return ProgressApplyResult(
        snapshot: snapshot,
        earnedTitles: newUnlockedTitles,
      );
    });
  }

  Future<UserProgressSnapshot> getProgress({
    required String uid,
  }) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data() ?? <String, dynamic>{};

    final int exp = _readInt(data['exp']);
    final int storedLevel = _readInt(data['level']);
    final int level = storedLevel > 0 ? storedLevel : calculateLevel(exp);

    final int registeredMachineCount = _readInt(data['registeredMachineCount']);
    final int registeredDrinkCount = _readInt(data['registeredDrinkCount']);
    final int checkinCount = _readInt(data['checkinCount']);

    final List<String> currentTitles = _readStringList(data['titles']);
    final List<String> expectedTitles = _resolveEarnedTitles(
      level: level,
      machineCount: registeredMachineCount,
      drinkCount: registeredDrinkCount,
      checkinCount: checkinCount,
    );
    final List<String> mergedTitles = _mergeTitles(currentTitles, expectedTitles);

    final String currentTitle = _readNullableString(data['currentTitle']) ??
        _resolveCurrentTitle(
          currentTitles: mergedTitles,
          fallback: _fallbackTitle,
        );

    if (_shouldBackfill(
      storedTitles: currentTitles,
      mergedTitles: mergedTitles,
      storedCurrentTitle: _readNullableString(data['currentTitle']),
      resolvedCurrentTitle: currentTitle,
      storedLevel: storedLevel,
      resolvedLevel: level,
    )) {
      await _users.doc(uid).set(
        <String, dynamic>{
          'level': level,
          'titles': mergedTitles,
          'currentTitle': currentTitle,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    return UserProgressSnapshot(
      exp: exp,
      level: level,
      currentTitle: currentTitle,
      titles: mergedTitles,
      registeredMachineCount: registeredMachineCount,
      registeredDrinkCount: registeredDrinkCount,
      checkinCount: checkinCount,
    );
  }

  bool _shouldBackfill({
    required List<String> storedTitles,
    required List<String> mergedTitles,
    required String? storedCurrentTitle,
    required String resolvedCurrentTitle,
    required int storedLevel,
    required int resolvedLevel,
  }) {
    if (storedTitles.length != mergedTitles.length) return true;
    if (!_sameStringList(storedTitles, mergedTitles)) return true;
    if ((storedCurrentTitle ?? '').trim() != resolvedCurrentTitle.trim()) return true;
    if (storedLevel != resolvedLevel) return true;
    return false;
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].trim() != b[i].trim()) return false;
    }
    return true;
  }

  String get _fallbackTitle =>
      titleRules.firstWhere((rule) => rule.fallback).title;

  int calculateLevel(int exp) {
    if (exp <= 0) return 1;

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

    var threshold = 100;
    var total = 0;

    while (exp >= total + threshold) {
      total += threshold;
      threshold += 50;
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
    required int level,
    required int machineCount,
    required int drinkCount,
    required int checkinCount,
  }) {
    final List<String> titles = <String>[];

    for (final rule in titleRules) {
      final bool machineOk =
          rule.minMachineCount == null || machineCount >= rule.minMachineCount!;
      final bool drinkOk =
          rule.minDrinkCount == null || drinkCount >= rule.minDrinkCount!;
      final bool checkinOk =
          rule.minCheckinCount == null || checkinCount >= rule.minCheckinCount!;
      final bool levelOk = rule.minLevel == null || level >= rule.minLevel!;

      final bool earned =
          rule.fallback || (machineOk && drinkOk && checkinOk && levelOk);
      if (earned) {
        titles.add(rule.title);
      }
    }

    return titles;
  }

  List<String> _mergeTitles(List<String> current, List<String> added) {
    final List<String> result = <String>[];
    final Set<String> used = <String>{};

    for (final title in <String>[...current, ...added]) {
      final String trimmed = title.trim();
      if (trimmed.isEmpty) continue;
      if (used.contains(trimmed)) continue;
      used.add(trimmed);
      result.add(trimmed);
    }

    return result;
  }

  List<String> _diffUnlockedTitles({
    required List<String> before,
    required List<String> after,
  }) {
    final Set<String> owned = before.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    return after.where((title) => !owned.contains(title.trim())).toList(growable: false);
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
    final String text = value.toString().trim();
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

class ProgressApplyResult {
  const ProgressApplyResult({
    required this.snapshot,
    required this.earnedTitles,
  });

  final UserProgressSnapshot? snapshot;
  final List<String> earnedTitles;

  bool get hasUnlockedTitles => earnedTitles.isNotEmpty;

  factory ProgressApplyResult.empty() {
    return const ProgressApplyResult(
      snapshot: null,
      earnedTitles: <String>[],
    );
  }
}

class TitleRule {
  const TitleRule({
    required this.title,
    required this.condition,
    this.minMachineCount,
    this.minDrinkCount,
    this.minCheckinCount,
    this.minLevel,
    this.fallback = false,
  });

  final String title;
  final String condition;
  final int? minMachineCount;
  final int? minDrinkCount;
  final int? minCheckinCount;
  final int? minLevel;
  final bool fallback;
}