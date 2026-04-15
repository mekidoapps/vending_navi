import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteDrinkService {
  FavoriteDrinkService._();

  static final FavoriteDrinkService instance = FavoriteDrinkService._();

  static const int freeLimit = 10;
  static const int premiumLimit = 100;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<List<String>> getFavoriteDrinkNames({
    String? uid,
  }) async {
    final resolvedUid = _resolveUid(uid);
    if (resolvedUid == null) return <String>[];

    final snapshot = await _users.doc(resolvedUid).get();
    final data = snapshot.data() ?? <String, dynamic>{};

    return _readStringList(data['favoriteDrinkNames']);
  }

  Stream<List<String>> watchFavoriteDrinkNames({
    String? uid,
  }) {
    final resolvedUid = _resolveUid(uid);
    if (resolvedUid == null) {
      return const Stream<List<String>>.empty();
    }

    return _users.doc(resolvedUid).snapshots().map((snapshot) {
      final data = snapshot.data() ?? <String, dynamic>{};
      return _readStringList(data['favoriteDrinkNames']);
    });
  }

  Future<bool> isFavorite(
      String drinkName, {
        String? uid,
      }) async {
    final favorites = await getFavoriteDrinkNames(uid: uid);
    final target = _normalize(drinkName);

    return favorites.any((e) => _normalize(e) == target);
  }

  Future<int> count({
    String? uid,
  }) async {
    final favorites = await getFavoriteDrinkNames(uid: uid);
    return favorites.length;
  }

  Future<int> getLimit({
    String? uid,
  }) async {
    final resolvedUid = _resolveUid(uid);
    if (resolvedUid == null) return freeLimit;

    try {
      final snapshot = await _users.doc(resolvedUid).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final isPremium = data['isPremium'] == true;
      return isPremium ? premiumLimit : freeLimit;
    } catch (_) {
      return freeLimit;
    }
  }

  Future<FavoriteDrinkMutationResult> addFavorite(
      String drinkName, {
        String? uid,
      }) async {
    final resolvedUid = _resolveUid(uid);
    if (resolvedUid == null) {
      return const FavoriteDrinkMutationResult(
        success: false,
        reason: FavoriteDrinkMutationReason.notLoggedIn,
      );
    }

    final trimmed = drinkName.trim();
    if (trimmed.isEmpty) {
      return const FavoriteDrinkMutationResult(
        success: false,
        reason: FavoriteDrinkMutationReason.invalidName,
      );
    }

    final current = await getFavoriteDrinkNames(uid: resolvedUid);
    final normalized = _normalize(trimmed);

    final alreadyExists = current.any((e) => _normalize(e) == normalized);
    if (alreadyExists) {
      return FavoriteDrinkMutationResult(
        success: true,
        reason: FavoriteDrinkMutationReason.alreadyExists,
        favorites: current,
      );
    }

    final limit = await getLimit(uid: resolvedUid);
    if (current.length >= limit) {
      return FavoriteDrinkMutationResult(
        success: false,
        reason: FavoriteDrinkMutationReason.limitReached,
        favorites: current,
        limit: limit,
      );
    }

    final next = <String>[...current, trimmed];

    await _users.doc(resolvedUid).set(
      <String, dynamic>{
        'favoriteDrinkNames': next,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return FavoriteDrinkMutationResult(
      success: true,
      reason: FavoriteDrinkMutationReason.added,
      favorites: next,
      limit: limit,
    );
  }

  Future<FavoriteDrinkMutationResult> removeFavorite(
      String drinkName, {
        String? uid,
      }) async {
    final resolvedUid = _resolveUid(uid);
    if (resolvedUid == null) {
      return const FavoriteDrinkMutationResult(
        success: false,
        reason: FavoriteDrinkMutationReason.notLoggedIn,
      );
    }

    final current = await getFavoriteDrinkNames(uid: resolvedUid);
    final normalized = _normalize(drinkName);

    final next = current
        .where((e) => _normalize(e) != normalized)
        .toList(growable: false);

    if (next.length == current.length) {
      return FavoriteDrinkMutationResult(
        success: true,
        reason: FavoriteDrinkMutationReason.notFound,
        favorites: current,
      );
    }

    await _users.doc(resolvedUid).set(
      <String, dynamic>{
        'favoriteDrinkNames': next,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return FavoriteDrinkMutationResult(
      success: true,
      reason: FavoriteDrinkMutationReason.removed,
      favorites: next,
    );
  }

  Future<void> replaceAllFavorites(
      List<String> drinkNames, {
        String? uid,
      }) async {
    final resolvedUid = _resolveUid(uid);
    if (resolvedUid == null) {
      throw StateError('ログインが必要です');
    }

    final deduped = <String>[];
    final used = <String>{};

    for (final name in drinkNames) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;

      final key = _normalize(trimmed);
      if (used.contains(key)) continue;

      used.add(key);
      deduped.add(trimmed);
    }

    final limit = await getLimit(uid: resolvedUid);
    final limited = deduped.take(limit).toList(growable: false);

    await _users.doc(resolvedUid).set(
      <String, dynamic>{
        'favoriteDrinkNames': limited,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  String? _resolveUid(String? uid) {
    final trimmed = uid?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    return currentUser.uid;
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];

    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('　', '')
        .replaceAll(' ', '')
        .replaceAll('〜', 'ー')
        .replaceAll('～', 'ー')
        .replaceAll('-', 'ー');
  }
}

enum FavoriteDrinkMutationReason {
  added,
  removed,
  alreadyExists,
  notFound,
  limitReached,
  notLoggedIn,
  invalidName,
}

class FavoriteDrinkMutationResult {
  const FavoriteDrinkMutationResult({
    required this.success,
    required this.reason,
    this.favorites = const <String>[],
    this.limit,
  });

  final bool success;
  final FavoriteDrinkMutationReason reason;
  final List<String> favorites;
  final int? limit;
}