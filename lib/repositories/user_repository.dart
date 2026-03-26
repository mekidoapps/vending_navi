import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_stats.dart';
import '../../services/firestore_service.dart';

class UserRepository {
  UserRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<UserStats?> fetchUserStats(String userId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestoreService.users().doc(userId).get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return UserStats.fromMap(doc.id, doc.data()!);
  }

  Stream<UserStats?> watchUserStats(String userId) {
    return _firestoreService.users().doc(userId).snapshots().map(
          (DocumentSnapshot<Map<String, dynamic>> doc) {
        if (!doc.exists || doc.data() == null) {
          return null;
        }
        return UserStats.fromMap(doc.id, doc.data()!);
      },
    );
  }

  Future<void> saveUserStats(UserStats stats) {
    return _firestoreService.users().doc(stats.userId).set(
      stats.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> ensureUserDocument({
    required String userId,
    required String displayName,
    String? photoUrl,
  }) {
    final DateTime now = DateTime.now();

    return _firestoreService.users().doc(userId).set(
      <String, dynamic>{
        'display_name': displayName,
        'photo_url': photoUrl,
        'checkin_count': 0,
        'machine_created_count': 0,
        'contribution_score': 0,
        'favorite_product_count': 0,
        'favorite_machine_count': 0,
        'current_title_id': null,
        'created_at': now,
        'updated_at': now,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> incrementCheckinCount(String userId, {int by = 1}) {
    return _firestoreService.users().doc(userId).set(
      <String, dynamic>{
        'checkin_count': FieldValue.increment(by),
        'updated_at': DateTime.now(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> incrementMachineCreatedCount(String userId, {int by = 1}) {
    return _firestoreService.users().doc(userId).set(
      <String, dynamic>{
        'machine_created_count': FieldValue.increment(by),
        'updated_at': DateTime.now(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> incrementContributionScore(String userId, {int by = 1}) {
    return _firestoreService.users().doc(userId).set(
      <String, dynamic>{
        'contribution_score': FieldValue.increment(by),
        'updated_at': DateTime.now(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateFavoriteCounts({
    required String userId,
    required int favoriteProductCount,
    required int favoriteMachineCount,
  }) {
    return _firestoreService.users().doc(userId).set(
      <String, dynamic>{
        'favorite_product_count': favoriteProductCount,
        'favorite_machine_count': favoriteMachineCount,
        'updated_at': DateTime.now(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateCurrentTitle({
    required String userId,
    required String? titleId,
  }) {
    return _firestoreService.users().doc(userId).set(
      <String, dynamic>{
        'current_title_id': titleId,
        'updated_at': DateTime.now(),
      },
      SetOptions(merge: true),
    );
  }
}