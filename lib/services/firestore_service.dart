import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vending_machine.dart';

class FirestoreService {
  FirestoreService._();

  static final instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  /// コレクション統一
  CollectionReference<Map<String, dynamic>> get _machines =>
      _db.collection('vending_machines');

  CollectionReference<Map<String, dynamic>> get _checkins =>
      _db.collection('checkins');

  // ===============================
  // 自販機取得（一覧）
  // ===============================
  Stream<List<VendingMachine>> watchMachines() {
    return _machines
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VendingMachine.fromFirestore(doc))
          .toList();
    });
  }

  // ===============================
  // 自販機取得（単体）
  // ===============================
  Future<VendingMachine?> getMachine(String id) async {
    final doc = await _machines.doc(id).get();
    if (!doc.exists) return null;
    return VendingMachine.fromFirestore(doc);
  }

  // ===============================
  // 自販機作成
  // ===============================
  Future<String> createMachine(VendingMachine machine) async {
    final now = DateTime.now();

    final doc = await _machines.add(
      machine.copyWith(
        createdAt: now,
        updatedAt: now,
        lastCheckedAt: now,
        checkinCount: 0,
      ).toFirestore(),
    );

    return doc.id;
  }

  // ===============================
  // 自販機更新
  // ===============================
  Future<void> updateMachine(VendingMachine machine) async {
    final now = DateTime.now();

    await _machines.doc(machine.id).update(
      machine.copyWith(
        updatedAt: now,
      ).toFirestore(),
    );
  }

  // ===============================
  // チェックイン
  // ===============================
  Future<void> checkin({
    required String machineId,
    required List<Map<String, dynamic>> drinkSlots,
  }) async {
    final now = DateTime.now();

    // 🔥 トランザクションで安全更新
    await _db.runTransaction((tx) async {
      final ref = _machines.doc(machineId);
      final snap = await tx.get(ref);

      if (!snap.exists) return;

      final currentCount = (snap.data()?['checkinCount'] ?? 0) as int;

      // 自販機更新
      tx.update(ref, {
        'drinkSlots': drinkSlots,
        'updatedAt': Timestamp.fromDate(now),
        'lastCheckedAt': Timestamp.fromDate(now),
        'checkinCount': currentCount + 1,
      });

      // チェックイン履歴保存
      tx.set(_checkins.doc(), {
        'machineId': machineId,
        'drinkSlots': drinkSlots,
        'createdAt': Timestamp.fromDate(now),
      });
    });
  }
}