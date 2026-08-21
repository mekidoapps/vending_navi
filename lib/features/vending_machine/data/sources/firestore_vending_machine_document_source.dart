import 'package:cloud_firestore/cloud_firestore.dart';

import 'vending_machine_document.dart';
import 'vending_machine_document_source.dart';

final class FirestoreVendingMachineDocumentSource
    implements VendingMachineDocumentSource {
  FirestoreVendingMachineDocumentSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<VendingMachineDocument>> fetchMachineDocuments() async {
    final snapshot = await _firestore
        .collection(VendingMachineCollections.vendingMachines)
        .where('status', isEqualTo: 'active')
        .get();

    return snapshot.docs
        .map(
          (document) => VendingMachineDocument(
            id: document.id,
            data: Map<String, dynamic>.from(document.data()),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<VendingMachineDocument?> fetchMachineDocument(String machineId) async {
    final snapshot = await _firestore
        .collection(VendingMachineCollections.vendingMachines)
        .doc(machineId)
        .get();

    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return VendingMachineDocument(
      id: snapshot.id,
      data: Map<String, dynamic>.from(data),
    );
  }

  @override
  Future<List<VendingMachineDocument>> fetchProductDocuments(
    String machineId,
  ) async {
    final snapshot = await _firestore
        .collection(VendingMachineCollections.vendingMachines)
        .doc(machineId)
        .collection(VendingMachineCollections.products)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs
        .map(
          (document) => VendingMachineDocument(
            id: document.id,
            data: Map<String, dynamic>.from(document.data()),
          ),
        )
        .toList(growable: false);
  }
}
