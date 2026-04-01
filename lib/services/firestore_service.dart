import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/drink_item.dart';
import '../models/vending_machine.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String vendingMachinesCollection = 'vending_machines';
  static const String drinksCollection = 'drinks';
  static const String usersCollection = 'users';
  static const String checkinsCollection = 'checkins';

  CollectionReference<Map<String, dynamic>> get _machinesRef =>
      _firestore.collection(vendingMachinesCollection);

  CollectionReference<Map<String, dynamic>> get _drinksRef =>
      _firestore.collection(drinksCollection);

  Future<List<VendingMachine>> fetchVendingMachines() async {
    final snapshot =
    await _machinesRef.orderBy('updatedAt', descending: true).get();

    return snapshot.docs
        .map(
          (doc) => VendingMachine.fromMap(
        doc.data(),
        documentId: doc.id,
      ),
    )
        .toList();
  }

  Stream<List<VendingMachine>> watchVendingMachines() {
    return _machinesRef
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => VendingMachine.fromMap(
          doc.data(),
          documentId: doc.id,
        ),
      )
          .toList(),
    );
  }

  Future<String> addVendingMachine(VendingMachine machine) async {
    final now = DateTime.now();

    final payload = machine.copyWith(
      createdAt: machine.createdAt ?? now,
      updatedAt: now,
      lastCheckedAt: machine.lastCheckedAt ?? now,
    );

    final doc = await _machinesRef.add(payload.toMap());
    await doc.update(<String, dynamic>{'id': doc.id});
    return doc.id;
  }

  Future<void> updateVendingMachine(VendingMachine machine) async {
    if (machine.id.isEmpty) {
      throw ArgumentError('machine.id is empty');
    }

    final payload = machine.copyWith(
      updatedAt: DateTime.now(),
    );

    await _machinesRef.doc(machine.id).set(
      payload.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<VendingMachine?> fetchVendingMachineById(String id) async {
    if (id.isEmpty) return null;

    final doc = await _machinesRef.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return VendingMachine.fromMap(
      doc.data()!,
      documentId: doc.id,
    );
  }

  Future<List<DrinkItem>> fetchDrinks() async {
    final snapshot = await _drinksRef.orderBy('name').get();

    return snapshot.docs
        .map(
          (doc) => DrinkItem.fromMap(
        doc.data(),
        documentId: doc.id,
      ),
    )
        .toList();
  }

  Stream<List<DrinkItem>> watchDrinks() {
    return _drinksRef.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => DrinkItem.fromMap(
          doc.data(),
          documentId: doc.id,
        ),
      )
          .toList(),
    );
  }

  Future<String> addDrink(DrinkItem drink) async {
    final doc = await _drinksRef.add(drink.toMap());
    await doc.update(<String, dynamic>{'id': doc.id});
    return doc.id;
  }

  Future<List<VendingMachine>> searchMachinesByKeyword(String keyword) async {
    final all = await fetchVendingMachines();
    final query = keyword.trim().toLowerCase();

    if (query.isEmpty) return all;

    return all.where((machine) {
      final matchesMachineName = machine.name.toLowerCase().contains(query);
      final matchesDrink =
      machine.drinks.any((drink) => drink.matches(query));
      final matchesAddressHint =
      machine.addressHint.toLowerCase().contains(query);

      return matchesMachineName || matchesDrink || matchesAddressHint;
    }).toList();
  }

  Future<List<DrinkItem>> searchDrinksByKeyword(String keyword) async {
    final all = await fetchDrinks();
    final query = keyword.trim();

    if (query.isEmpty) return all;
    return all.where((drink) => drink.matches(query)).toList();
  }

  Future<void> addCheckin({
    required String userId,
    required String machineId,
  }) async {
    if (userId.isEmpty || machineId.isEmpty) {
      throw ArgumentError('userId or machineId is empty');
    }

    final now = DateTime.now();

    await _firestore.collection(checkinsCollection).add(<String, dynamic>{
      'userId': userId,
      'machineId': machineId,
      'createdAt': Timestamp.fromDate(now),
    });

    await _machinesRef.doc(machineId).set(
      <String, dynamic>{
        'lastCheckedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'checkinCount': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> createMachineFromForm({
    required String machineName,
    required String addressHint,
    required List<String> tags,
    required List<String> photoUrls,
    required List<String> drinkNames,
    required String paymentLabel,
    double latitude = 35.0,
    double longitude = 139.0,
  }) async {
    final drinks = drinkNames
        .map(
          (name) => DrinkItem(
        id: name,
        name: name,
        brand: '',
        category: '',
      ),
    )
        .toList();

    final machine = VendingMachine(
      id: '',
      name: machineName.trim().isEmpty ? '新しい自販機' : machineName.trim(),
      latitude: latitude,
      longitude: longitude,
      distanceMeters: 0,
      addressHint: addressHint,
      paymentLabel: paymentLabel,
      updatedLabel: '今日更新',
      tags: tags,
      drinks: drinks,
      photoUrls: photoUrls,
      reliabilityScore: 60,
      hasFavoriteMatch: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastCheckedAt: DateTime.now(),
      checkinCount: 0,
    );

    return addVendingMachine(machine);
  }
}