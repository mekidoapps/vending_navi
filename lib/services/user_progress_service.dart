import 'package:cloud_firestore/cloud_firestore.dart';

class UserProgressService {
  UserProgressService._();

  static const int xpPerCheckin = 10;
  static const int xpPerMachineRegister = 50;
  static const int xpPerDrinkRegister = 5;

  static Future<void> applyMachineRegisterProgress({
    required String uid,
    required String displayName,
    required int addedDrinkCount,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? <String, dynamic>{};

      final currentMachineRegisterCount =
      _readInt(data['machineRegisterCount']);
      final currentDrinkRegisterCount = _readInt(data['drinkRegisterCount']);
      final currentXp = _readInt(data['xp']);

      final nextMachineRegisterCount = currentMachineRegisterCount + 1;
      final nextDrinkRegisterCount = currentDrinkRegisterCount + addedDrinkCount;

      final gainedXp =
          xpPerMachineRegister + (addedDrinkCount * xpPerDrinkRegister);
      final nextXp = currentXp + gainedXp;

      final nextTitle = _inferCurrentTitle(
        checkinCount: _readInt(data['checkinCount']),
        machineRegisterCount: nextMachineRegisterCount,
        drinkRegisterCount: nextDrinkRegisterCount,
        xp: nextXp,
      );

      transaction.set(
        userRef,
        <String, dynamic>{
          'displayName': displayName,
          'machineRegisterCount': nextMachineRegisterCount,
          'drinkRegisterCount': nextDrinkRegisterCount,
          'xp': nextXp,
          'currentTitle': nextTitle,
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMachineRegisteredAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  static int calcLevelFromXp(int xp) {
    if (xp <= 0) return 1;
    return (xp ~/ 100) + 1;
  }

  static String inferTitleFromData(Map<String, dynamic> data) {
    return _inferCurrentTitle(
      checkinCount: _readInt(data['checkinCount']),
      machineRegisterCount: _readInt(data['machineRegisterCount']),
      drinkRegisterCount: _readInt(data['drinkRegisterCount']),
      xp: _readInt(data['xp']),
    );
  }

  static String _inferCurrentTitle({
    required int checkinCount,
    required int machineRegisterCount,
    required int drinkRegisterCount,
    required int xp,
  }) {
    final level = calcLevelFromXp(xp);

    if (machineRegisterCount >= 10) return 'エリア探索者';
    if (drinkRegisterCount >= 30) return 'ドリンクメモ職人';
    if (checkinCount >= 10) return '街角ハンター';
    if (level >= 3) return 'ルーキーナビゲーター';
    if (machineRegisterCount >= 1) return 'はじめての一台';
    return 'これからの探索者';
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}