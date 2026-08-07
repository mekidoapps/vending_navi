import 'package:cloud_firestore/cloud_firestore.dart';

import 'master_document.dart';
import 'master_document_source.dart';

final class FirestoreMasterDocumentSource implements MasterDocumentSource {
  FirestoreMasterDocumentSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<MasterDocument>> fetchCollection(String collectionPath) async {
    final snapshot = await _firestore.collection(collectionPath).get();

    return snapshot.docs
        .map(
          (document) => MasterDocument(
            id: document.id,
            data: Map<String, dynamic>.from(document.data()),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<MasterDocument?> fetchDocument(
    String collectionPath,
    String documentId,
  ) async {
    final snapshot = await _firestore
        .collection(collectionPath)
        .doc(documentId)
        .get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return MasterDocument(
      id: snapshot.id,
      data: Map<String, dynamic>.from(data),
    );
  }
}
