import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/vending_machine.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _machines =>
      _db.collection('vending_machines');

  CollectionReference<Map<String, dynamic>> get _checkins =>
      _db.collection('checkins');

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

  Future<List<VendingMachine>> fetchMachines() async {
    final snapshot = await _machines.orderBy('updatedAt', descending: true).get();
    return snapshot.docs.map((doc) => VendingMachine.fromFirestore(doc)).toList();
  }

  Future<VendingMachine?> getMachine(String id) async {
    if (id.trim().isEmpty) return null;

    final doc = await _machines.doc(id).get();
    if (!doc.exists) return null;

    return VendingMachine.fromFirestore(doc);
  }

  Future<String> createMachine(VendingMachine machine) async {
    final now = DateTime.now();
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _resolveDisplayName(user);

    final machineData = machine.copyWith(
      createdAt: now,
      updatedAt: now,
      lastCheckedAt: now,
      checkinCount: 0,
    ).toFirestore();

    machineData['createdAt'] = Timestamp.fromDate(now);
    machineData['updatedAt'] = Timestamp.fromDate(now);
    machineData['lastCheckedAt'] = Timestamp.fromDate(now);
    machineData['memo'] = machine.note;

    if (user != null) {
      machineData['createdBy'] = user.uid;
      machineData['updatedBy'] = user.uid;
      machineData['createdByName'] = displayName;
      machineData['updatedByName'] = displayName;
    }

    final doc = await _machines.add(machineData);
    return doc.id;
  }

  Future<void> updateMachine(VendingMachine machine) async {
    if (machine.id.trim().isEmpty) {
      throw ArgumentError('machine.id is empty');
    }

    final now = DateTime.now();
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _resolveDisplayName(user);

    final machineData = machine.copyWith(
      updatedAt: now,
    ).toFirestore();

    machineData['updatedAt'] = Timestamp.fromDate(now);
    machineData['memo'] = machine.note;

    if (user != null) {
      machineData['updatedBy'] = user.uid;
      machineData['updatedByName'] = displayName;
    }

    await _machines.doc(machine.id).set(
      machineData,
      SetOptions(merge: true),
    );
  }

  Future<void> updateMachinePhoto({
    required String machineId,
    required String imageUrl,
  }) async {
    if (machineId.trim().isEmpty) {
      throw ArgumentError('machineId is empty');
    }

    await _machines.doc(machineId).set(
      <String, dynamic>{
        'imageUrl': imageUrl.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateMachineProducts({
    required String machineId,
    required List<Map<String, dynamic>> products,
    bool touchLastCheckedAt = true,
  }) async {
    if (machineId.trim().isEmpty) {
      throw ArgumentError('machineId is empty');
    }

    final payload = <String, dynamic>{
      'products': products,
      'drinkSlots': products,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (touchLastCheckedAt) {
      payload['lastCheckedAt'] = FieldValue.serverTimestamp();
    }

    await _machines.doc(machineId).set(
      payload,
      SetOptions(merge: true),
    );
  }

  Future<void> checkin({
    required String machineId,
    required List<Map<String, dynamic>> drinkSlots,
  }) async {
    if (machineId.trim().isEmpty) {
      throw ArgumentError('machineId is empty');
    }

    final now = DateTime.now();
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _resolveDisplayName(user);

    await _db.runTransaction((tx) async {
      final ref = _machines.doc(machineId);
      final snap = await tx.get(ref);

      if (!snap.exists) {
        throw StateError('対象の自販機が見つかりません');
      }

      final data = snap.data() ?? <String, dynamic>{};
      final currentCount = _readInt(data['checkinCount']);

      final updateData = <String, dynamic>{
        'products': drinkSlots,
        'drinkSlots': drinkSlots,
        'updatedAt': Timestamp.fromDate(now),
        'lastCheckedAt': Timestamp.fromDate(now),
        'checkinCount': currentCount + 1,
      };

      if (user != null) {
        updateData['updatedBy'] = user.uid;
        updateData['updatedByName'] = displayName;
      }

      tx.update(ref, updateData);

      tx.set(_checkins.doc(), <String, dynamic>{
        'machineId': machineId,
        'drinkSlots': drinkSlots,
        'createdAt': Timestamp.fromDate(now),
        if (user != null) 'uid': user.uid,
        if (user != null) 'displayName': displayName,
      });
    });
  }

  Future<void> deleteMachine(String machineId) async {
    if (machineId.trim().isEmpty) {
      throw ArgumentError('machineId is empty');
    }

    await _machines.doc(machineId).delete();
  }

  Future<int> countMachinesCreatedBy(String uid) async {
    if (uid.trim().isEmpty) return 0;

    try {
      final snapshot = await _machines.where('createdBy', isEqualTo: uid).get();
      return snapshot.docs.length;
    } catch (_) {
      return 0;
    }
  }

  String _resolveDisplayName(User? user) {
    if (user == null) return 'ユーザー';

    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;

    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email;

    return 'ユーザー';
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}