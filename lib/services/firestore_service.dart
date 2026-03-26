import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._internal();

  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseFirestore get instance => _firestore;

  CollectionReference<Map<String, dynamic>> users() {
    return _firestore.collection('users');
  }

  CollectionReference<Map<String, dynamic>> vendingMachines() {
    return _firestore.collection('vending_machines');
  }

  CollectionReference<Map<String, dynamic>> productMaster() {
    return _firestore.collection('product_master');
  }

  CollectionReference<Map<String, dynamic>> machineItems() {
    return _firestore.collection('machine_items');
  }

  CollectionReference<Map<String, dynamic>> checkins() {
    return _firestore.collection('checkins');
  }

  CollectionReference<Map<String, dynamic>> favorites() {
    return _firestore.collection('favorites');
  }

  CollectionReference<Map<String, dynamic>> titleMaster() {
    return _firestore.collection('title_master');
  }

  CollectionReference<Map<String, dynamic>> userTitles() {
    return _firestore.collection('user_titles');
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument({
    required String collectionPath,
    required String documentId,
  }) {
    return _firestore.collection(collectionPath).doc(documentId).get();
  }

  Future<void> setDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) {
    return _firestore.collection(collectionPath).doc(documentId).set(
      data,
      SetOptions(merge: merge),
    );
  }

  Future<void> addDocument({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) {
    return _firestore.collection(collectionPath).add(data);
  }

  Future<void> updateDocument({
    required String collectionPath,
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return _firestore.collection(collectionPath).doc(documentId).update(data);
  }

  Future<void> deleteDocument({
    required String collectionPath,
    required String documentId,
  }) {
    return _firestore.collection(collectionPath).doc(documentId).delete();
  }

  WriteBatch batch() => _firestore.batch();

  Future<T> runTransaction<T>(
      TransactionHandler<T> transactionHandler,
      ) {
    return _firestore.runTransaction(transactionHandler);
  }

  Timestamp now() => Timestamp.now();
}