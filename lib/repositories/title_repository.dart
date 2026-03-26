import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';

class TitleMasterItem {
  final String id;
  final String name;
  final String description;
  final String category;
  final String unlockType;
  final int unlockThreshold;
  final int sortOrder;
  final bool isHidden;

  const TitleMasterItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.unlockType,
    required this.unlockThreshold,
    required this.sortOrder,
    this.isHidden = false,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'description': description,
      'category': category,
      'unlock_type': unlockType,
      'unlock_threshold': unlockThreshold,
      'sort_order': sortOrder,
      'is_hidden': isHidden,
    };
  }

  factory TitleMasterItem.fromMap(String id, Map<String, dynamic> map) {
    return TitleMasterItem(
      id: id,
      name: (map['name'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      unlockType: (map['unlock_type'] ?? '') as String,
      unlockThreshold: (map['unlock_threshold'] ?? 0) as int,
      sortOrder: (map['sort_order'] ?? 0) as int,
      isHidden: (map['is_hidden'] ?? false) as bool,
    );
  }
}

class UserTitleItem {
  final String id;
  final String userId;
  final String titleId;
  final DateTime? acquiredAt;
  final bool isEquipped;

  const UserTitleItem({
    required this.id,
    required this.userId,
    required this.titleId,
    this.acquiredAt,
    this.isEquipped = false,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'title_id': titleId,
      'acquired_at': acquiredAt,
      'is_equipped': isEquipped,
    };
  }

  factory UserTitleItem.fromMap(String id, Map<String, dynamic> map) {
    return UserTitleItem(
      id: id,
      userId: (map['user_id'] ?? '') as String,
      titleId: (map['title_id'] ?? '') as String,
      acquiredAt: _toDateTime(map['acquired_at']),
      isEquipped: (map['is_equipped'] ?? false) as bool,
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

class TitleRepository {
  TitleRepository({
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<List<TitleMasterItem>> fetchTitleMaster({
    int limit = 200,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestoreService.titleMaster().limit(limit).get();

    final List<TitleMasterItem> items = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return TitleMasterItem.fromMap(doc.id, doc.data());
    }).toList();

    items.sort((TitleMasterItem a, TitleMasterItem b) {
      return a.sortOrder.compareTo(b.sortOrder);
    });

    return items;
  }

  Future<List<UserTitleItem>> fetchUserTitles({
    required String userId,
    int limit = 200,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestoreService
        .userTitles()
        .where('user_id', isEqualTo: userId)
        .limit(limit)
        .get();

    final List<UserTitleItem> items = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      return UserTitleItem.fromMap(doc.id, doc.data());
    }).toList();

    items.sort((UserTitleItem a, UserTitleItem b) {
      final DateTime aDate = a.acquiredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate = b.acquiredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return items;
  }

  Future<void> grantTitle({
    required String userId,
    required String titleId,
  }) async {
    final String docId = '${userId}_$titleId';

    await _firestoreService.userTitles().doc(docId).set(
      <String, dynamic>{
        'user_id': userId,
        'title_id': titleId,
        'acquired_at': DateTime.now(),
        'is_equipped': false,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> equipTitle({
    required String userId,
    required String titleId,
  }) async {
    final List<UserTitleItem> current = await fetchUserTitles(userId: userId);

    final WriteBatch batch = _firestoreService.batch();

    for (final UserTitleItem item in current) {
      final DocumentReference<Map<String, dynamic>> ref =
      _firestoreService.userTitles().doc(item.id);

      batch.set(
        ref,
        <String, dynamic>{
          'is_equipped': item.titleId == titleId,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<bool> hasTitle({
    required String userId,
    required String titleId,
  }) async {
    final String docId = '${userId}_$titleId';
    final DocumentSnapshot<Map<String, dynamic>> doc =
    await _firestoreService.userTitles().doc(docId).get();
    return doc.exists;
  }
}