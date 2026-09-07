import 'package:cloud_firestore/cloud_firestore.dart';

import 'vending_machine_document.dart';

final class FirestoreMachinePhotoSource {
  FirestoreMachinePhotoSource(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<VendingMachineDocument>> fetchActive(String machineId) async {
    final snapshot = await _firestore
        .collection('vending_machines')
        .doc(machineId)
        .collection('photos')
        .where('status', isEqualTo: 'active')
        .get();
    return snapshot.docs
        .map((document) => VendingMachineDocument(
              id: document.id,
              data: Map<String, dynamic>.from(document.data()),
            ))
        .toList(growable: false);
  }
}
