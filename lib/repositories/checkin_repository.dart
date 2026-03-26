import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/checkin.dart';
import '../../models/vending_machine_access.dart';
import '../../services/firestore_service.dart';

class CheckinRepository {
  CheckinRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<String> createCheckin(Checkin checkin) async {
    final DocumentReference<Map<String, dynamic>> ref =
    _firestoreService.checkins().doc();

    final Checkin newCheckin = checkin.copyWith(id: ref.id);

    await ref.set(newCheckin.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  Future<List<Checkin>> fetchCheckinsByUserId(
      String userId, {
        int limit = 50,
      }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestoreService
        .checkins()
        .where('user_id', isEqualTo: userId)
        .limit(limit)
        .get();

    final List<Checkin> items = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return Checkin.fromMap(doc.id, doc.data());
    }).toList();

    items.sort((Checkin a, Checkin b) {
      final DateTime aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<List<Checkin>> fetchCheckinsByMachineId(
      String machineId, {
        int limit = 50,
      }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestoreService
        .checkins()
        .where('machine_id', isEqualTo: machineId)
        .limit(limit)
        .get();

    final List<Checkin> items = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return Checkin.fromMap(doc.id, doc.data());
    }).toList();

    items.sort((Checkin a, Checkin b) {
      final DateTime aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<void> saveMachineItemAfterCheckin({
    required VendingMachineAccess item,
  }) {
    return _firestoreService.machineItems().doc(item.id).set(
      item.toMap(),
      SetOptions(merge: true),
    );
  }
}