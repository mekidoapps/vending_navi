import 'package:cloud_firestore/cloud_firestore.dart';

import '../dtos/favorite_product_record_dto.dart';
import '../dtos/favorite_products_snapshot_dto.dart';
import 'favorite_products_data_source.dart';

final class FirestoreFavoriteProductsDataSource
    implements FavoriteProductsDataSource {
  const FirestoreFavoriteProductsDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  @override
  Future<FavoriteProductsSnapshotDto> load({required String uid}) async {
    final normalizedUid = _validatedUid(uid);
    final userReference = _users.doc(normalizedUid);

    final favoriteSnapshot = await userReference
        .collection('favorite_products')
        .orderBy('sortOrder')
        .get();

    final records = <FavoriteProductRecordDto>[
      for (final document in favoriteSnapshot.docs)
        FavoriteProductRecordDto.fromFirestore(
          documentId: document.id,
          data: document.data(),
        ),
    ];

    final userSnapshot = await userReference.get();
    final userData = userSnapshot.data() ?? const <String, dynamic>{};
    final migrationSnapshot = await userReference
        .collection('migration_state')
        .doc('favorite_products')
        .get();

    return FavoriteProductsSnapshotDto(
      records: List<FavoriteProductRecordDto>.unmodifiable(records),
      legacyFavoriteNames: _readStringList(userData['favoriteDrinkNames']),
      legacyMigrationCompleted: migrationSnapshot.exists,
    );
  }

  @override
  Future<void> add({
    required String uid,
    required String productId,
    required int sortOrder,
  }) {
    final normalizedUid = _validatedUid(uid);
    final normalizedProductId = _validatedProductId(productId);
    if (sortOrder < 0) {
      throw ArgumentError.value(
        sortOrder,
        'sortOrder',
        'sortOrder must not be negative',
      );
    }

    final reference = _users
        .doc(normalizedUid)
        .collection('favorite_products')
        .doc(normalizedProductId);

    return _firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) {
        return;
      }

      transaction.set(reference, <String, dynamic>{
        'productId': normalizedProductId,
        'sortOrder': sortOrder,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> remove({required String uid, required String productId}) {
    final normalizedUid = _validatedUid(uid);
    final normalizedProductId = _validatedProductId(productId);

    return _users
        .doc(normalizedUid)
        .collection('favorite_products')
        .doc(normalizedProductId)
        .delete();
  }

  @override
  Future<void> materializeLegacyFallback({
    required String uid,
    required List<String> productIds,
  }) async {
    final normalizedUid = _validatedUid(uid);
    final normalizedIds = <String>[];
    final usedIds = <String>{};

    for (final productId in productIds) {
      final normalizedProductId = _validatedProductId(productId);
      if (usedIds.add(normalizedProductId)) {
        normalizedIds.add(normalizedProductId);
      }
    }

    final userReference = _users.doc(normalizedUid);
    final batch = _firestore.batch();

    for (var index = 0; index < normalizedIds.length; index += 1) {
      final productId = normalizedIds[index];
      final reference = userReference
          .collection('favorite_products')
          .doc(productId);

      batch.set(reference, <String, dynamic>{
        'productId': productId,
        'sortOrder': index,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(
      userReference.collection('migration_state').doc('favorite_products'),
      <String, dynamic>{'completedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  static String _validatedUid(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'uid', 'uid must not be empty');
    }
    return normalized;
  }

  static String _validatedProductId(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError.value(
        value,
        'productId',
        'productId must be a Firestore-safe document id',
      );
    }
    return normalized;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
