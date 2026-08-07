import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../vending_machine/data/sources/vending_machine_document.dart';
import 'vending_machine_viewport_source.dart';

final class FirestoreVendingMachineViewportSource
    implements VendingMachineViewportSource {
  FirestoreVendingMachineViewportSource(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<VendingMachineDocument>> fetchV2ByGeohashPrefixes(
    Set<String> prefixes,
  ) async {
    if (prefixes.isEmpty) {
      return const <VendingMachineDocument>[];
    }

    final collection = _firestore.collection('vending_machines');
    final snapshots = await Future.wait(
      prefixes.map(
        (prefix) => collection
            .where('geohash', isGreaterThanOrEqualTo: prefix)
            .where('geohash', isLessThanOrEqualTo: '$prefix\uf8ff')
            .get(),
      ),
    );

    final documents = <String, VendingMachineDocument>{};

    for (final snapshot in snapshots) {
      for (final document in snapshot.docs) {
        final data = Map<String, dynamic>.from(document.data());
        if (_schemaVersion(data) < 2) {
          continue;
        }

        documents[document.id] = VendingMachineDocument(
          id: document.id,
          data: data,
        );
      }
    }

    return List<VendingMachineDocument>.unmodifiable(documents.values);
  }

  @override
  Future<List<VendingMachineDocument>> fetchLegacyDocuments() async {
    final snapshot = await _firestore.collection('vending_machines').get();

    return snapshot.docs
        .map(
          (document) => VendingMachineDocument(
            id: document.id,
            data: Map<String, dynamic>.from(document.data()),
          ),
        )
        .where((document) => _schemaVersion(document.data) < 2)
        .toList(growable: false);
  }

  static int _schemaVersion(Map<String, dynamic> data) {
    final raw = data['schemaVersion'];
    return switch (raw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 1,
      _ => 1,
    };
  }
}
