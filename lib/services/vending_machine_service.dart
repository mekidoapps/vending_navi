import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/drink_slot_data.dart';

class VendingMachineService {
  VendingMachineService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<String> createMachine({
    required double latitude,
    required double longitude,
    required String manufacturer,
    String? memo,
    String? placeNote,
    String? createdBy,
    required List<DrinkSlotData> drinkSlots,
  }) async {
    final DocumentReference<Map<String, dynamic>> doc =
    _firestore.collection('vending_machines').doc();

    final List<Map<String, dynamic>> slotMaps = drinkSlots
        .map((slot) => slot.toMap())
        .toList(growable: false);

    final List<String> drinkNames = drinkSlots
        .map((slot) => (slot.name ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    await doc.set(<String, dynamic>{
      'name': '未設定の自販機',
      'manufacturer': manufacturer,
      'lat': latitude,
      'lng': longitude,
      'latitude': latitude,
      'longitude': longitude,
      'memo': memo,
      'placeNote': placeNote,
      'createdBy': createdBy,
      'drinkSlots': slotMaps,
      'products': slotMaps,
      'drinks': drinkNames,
      'tags': const <String>[],
      'checkinCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastCheckedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }
}
