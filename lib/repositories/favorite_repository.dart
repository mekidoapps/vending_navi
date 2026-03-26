import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/favorite_drink_notification.dart';
import '../../services/firestore_service.dart';

class FavoriteItem {
  final String id;
  final String userId;
  final String targetType;
  final String targetId;
  final String targetNameSnapshot;
  final String? targetPhotoUrl;
  final bool notifyEnabled;
  final DateTime? createdAt;

  const FavoriteItem({
    required this.id,
    required this.userId,
    required this.targetType,
    required this.targetId,
    required this.targetNameSnapshot,
    this.targetPhotoUrl,
    this.notifyEnabled = true,
    this.createdAt,
  });

  FavoriteItem copyWith({
    String? id,
    String? userId,
    String? targetType,
    String? targetId,
    String? targetNameSnapshot,
    String? targetPhotoUrl,
    bool? notifyEnabled,
    DateTime? createdAt,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      targetNameSnapshot: targetNameSnapshot ?? this.targetNameSnapshot,
      targetPhotoUrl: targetPhotoUrl ?? this.targetPhotoUrl,
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'target_type': targetType,
      'target_id': targetId,
      'target_name_snapshot': targetNameSnapshot,
      'target_photo_url': targetPhotoUrl,
      'notify_enabled': notifyEnabled,
      'created_at': createdAt,
    };
  }

  factory FavoriteItem.fromMap(String id, Map<String, dynamic> map) {
    return FavoriteItem(
      id: id,
      userId: (map['user_id'] ?? '') as String,
      targetType: (map['target_type'] ?? '') as String,
      targetId: (map['target_id'] ?? '') as String,
      targetNameSnapshot: (map['target_name_snapshot'] ?? '') as String,
      targetPhotoUrl: map['target_photo_url'] as String?,
      notifyEnabled: (map['notify_enabled'] ?? true) as bool,
      createdAt: _toDateTime(map['created_at']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return value.toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}

class FavoriteRepository {
  FavoriteRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  String buildFavoriteId({
    required String userId,
    required String targetType,
    required String targetId,
  }) {
    return '${userId}_${targetType}_$targetId';
  }

  Future<void> saveFavorite(FavoriteItem item) {
    return _firestoreService.favorites().doc(item.id).set(
      item.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> removeFavorite({
    required String userId,
    required String targetType,
    required String targetId,
  }) {
    final String docId = buildFavoriteId(
      userId: userId,
      targetType: targetType,
      targetId: targetId,
    );

    return _firestoreService.favorites().doc(docId).delete();
  }

  Future<bool> isFavorite({
    required String userId,
    required String targetType,
    required String targetId,
  }) async {
    final String docId = buildFavoriteId(
      userId: userId,
      targetType: targetType,
      targetId: targetId,
    );

    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestoreService.favorites().doc(docId).get();

    return doc.exists;
  }

  Future<List<FavoriteItem>> fetchFavoritesByUser({
    required String userId,
    String? targetType,
    int limit = 100,
  }) async {
    Query<Map<String, dynamic>> query = _firestoreService
        .favorites()
        .where('user_id', isEqualTo: userId)
        .limit(limit);

    if (targetType != null && targetType.isNotEmpty) {
      query = query.where('target_type', isEqualTo: targetType);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

    final List<FavoriteItem> items = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return FavoriteItem.fromMap(doc.id, doc.data());
    }).toList();

    items.sort((FavoriteItem a, FavoriteItem b) {
      final DateTime aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<int> countFavoritesByType({
    required String userId,
    required String targetType,
  }) async {
    final List<FavoriteItem> items = await fetchFavoritesByUser(
      userId: userId,
      targetType: targetType,
      limit: 500,
    );
    return items.length;
  }

  Future<void> updateNotifyEnabled({
    required String favoriteId,
    required bool enabled,
  }) {
    return _firestoreService.favorites().doc(favoriteId).set(
      <String, dynamic>{
        'notify_enabled': enabled,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveNotification(FavoriteDrinkNotification notification) {
    return _firestoreService
        .instance
        .collection('favorite_drink_notifications')
        .doc(notification.id)
        .set(notification.toMap(), SetOptions(merge: true));
  }
}