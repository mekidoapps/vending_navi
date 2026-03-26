import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/vending_machine.dart';
import '../../models/vending_machine_access.dart';
import '../../services/firestore_service.dart';

class MachineRepository {
  MachineRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<List<VendingMachine>> fetchMachines({
    int limit = 100,
    bool onlyActive = true,
  }) async {
    Query<Map<String, dynamic>> query = _firestoreService.vendingMachines().limit(limit);

    if (onlyActive) {
      query = query.where('status', isEqualTo: 'active');
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return VendingMachine.fromMap(doc.id, doc.data());
    }).toList();
  }

  Future<VendingMachine?> fetchMachineById(String machineId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestoreService.vendingMachines().doc(machineId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return VendingMachine.fromMap(doc.id, doc.data()!);
  }

  Stream<VendingMachine?> watchMachineById(String machineId) {
    return _firestoreService.vendingMachines().doc(machineId).snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> doc) {
        if (!doc.exists || doc.data() == null) {
          return null;
        }
        return VendingMachine.fromMap(doc.id, doc.data()!);
      },
    );
  }

  Future<List<VendingMachineAccess>> fetchMachineItemsByMachineId(
      String machineId, {
        int limit = 100,
      }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestoreService
        .machineItems()
        .where('machine_id', isEqualTo: machineId)
        .limit(limit)
        .get();

    final List<VendingMachineAccess> items = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return VendingMachineAccess.fromMap(doc.id, doc.data());
    }).toList();

    items.sort((VendingMachineAccess a, VendingMachineAccess b) {
      return a.productNameSnapshot.compareTo(b.productNameSnapshot);
    });

    return items;
  }

  Future<List<VendingMachineAccess>> fetchMachineItemsByProductId(
      String productId, {
        int limit = 100,
      }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestoreService
        .machineItems()
        .where('product_id', isEqualTo: productId)
        .limit(limit)
        .get();

    return snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return VendingMachineAccess.fromMap(doc.id, doc.data());
    }).toList();
  }

  Future<String> createMachine(VendingMachine machine) async {
    final DocumentReference<Map<String, dynamic>> ref =
    _firestoreService.vendingMachines().doc();

    final VendingMachine newMachine = machine.copyWith(id: ref.id);

    await ref.set(newMachine.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  Future<void> saveMachine(VendingMachine machine) {
    return _firestoreService.vendingMachines().doc(machine.id).set(
      machine.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> saveMachineItem(VendingMachineAccess item) {
    return _firestoreService.machineItems().doc(item.id).set(
      item.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> updateMachineLastVerified({
    required String machineId,
    required DateTime verifiedAt,
  }) {
    return _firestoreService.vendingMachines().doc(machineId).set(
      <String, dynamic>{
        'last_verified_at': verifiedAt,
        'updated_at': DateTime.now(),
      },
      SetOptions(merge: true),
    );
  }
}