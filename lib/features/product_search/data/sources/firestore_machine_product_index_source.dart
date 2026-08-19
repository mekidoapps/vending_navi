import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../product_master/domain/value_objects/master_id.dart';
import 'machine_product_index_document.dart';
import 'machine_product_index_source.dart';

final class FirestoreMachineProductIndexSource
    implements MachineProductIndexSource {
  FirestoreMachineProductIndexSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<MachineProductIndexDocument>> fetchByProductAndGeohashPrefixes({
    required ProductId productId,
    required Set<String> geohashPrefixes,
  }) async {
    if (geohashPrefixes.isEmpty) {
      return const <MachineProductIndexDocument>[];
    }

    final collection = _firestore.collection('machine_product_index');

    final snapshots = await Future.wait(
      geohashPrefixes.map(
        (prefix) => collection
            .where('productId', isEqualTo: productId.value)
            .where('isActive', isEqualTo: true)
            .where('machineStatus', isEqualTo: 'active')
            .where('geohash', isGreaterThanOrEqualTo: prefix)
            .where('geohash', isLessThanOrEqualTo: '$prefix\uf8ff')
            .get(),
      ),
    );

    final documents = <String, MachineProductIndexDocument>{};

    for (final snapshot in snapshots) {
      for (final document in snapshot.docs) {
        documents[document.id] = MachineProductIndexDocument(
          id: document.id,
          data: Map<String, dynamic>.from(document.data()),
        );
      }
    }

    return List<MachineProductIndexDocument>.unmodifiable(documents.values);
  }
}
