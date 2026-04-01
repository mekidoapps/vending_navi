import 'package:cloud_firestore/cloud_firestore.dart';

import 'drink_item.dart';

class VendingMachine {
  const VendingMachine({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.addressHint,
    required this.paymentLabel,
    required this.updatedLabel,
    required this.tags,
    required this.drinks,
    required this.photoUrls,
    required this.reliabilityScore,
    required this.hasFavoriteMatch,
    this.createdAt,
    this.updatedAt,
    this.lastCheckedAt,
    this.checkinCount = 0,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String addressHint;
  final String paymentLabel;
  final String updatedLabel;
  final List<String> tags;
  final List<DrinkItem> drinks;
  final List<String> photoUrls;
  final int reliabilityScore;
  final bool hasFavoriteMatch;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastCheckedAt;
  final int checkinCount;

  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }

  String get walkingText {
    final minutes = (distanceMeters / 80).ceil();
    return '徒歩$minutes分';
  }

  String get headline {
    if (drinks.isEmpty) {
      return 'ドリンク情報なし';
    }

    final names = drinks.take(3).map((e) => e.name).toList();
    final label = names.join(' / ');
    return drinks.length > 3 ? '$label ほか' : '$label あり';
  }

  List<DrinkItem> matchedDrinks(String query) {
    if (query.trim().isEmpty) return drinks;
    return drinks.where((drink) => drink.matches(query)).toList();
  }

  factory VendingMachine.fromMap(
      Map<String, dynamic> map, {
        String? documentId,
      }) {
    final drinksRaw = (map['drinks'] as List<dynamic>?) ?? const [];
    final productsRaw = (map['products'] as List<dynamic>?) ?? const [];
    final rawPhotoUrls = (map['photoUrls'] as List<dynamic>?) ??
        (map['imageUrls'] as List<dynamic>?) ??
        _photoUrlsFromSingleImage(map) ??
        const <dynamic>[];

    final List<DrinkItem> parsedDrinks;
    if (drinksRaw.isNotEmpty) {
      parsedDrinks = drinksRaw
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (e) => DrinkItem.fromMap(
          Map<String, dynamic>.from(e),
        ),
      )
          .toList();
    } else {
      parsedDrinks = productsRaw
          .map(
            (e) => DrinkItem(
          id: e.toString(),
          name: e.toString(),
          brand: '',
          category: '',
        ),
      )
          .toList();
    }

    return VendingMachine(
      id: (map['id'] as String?)?.trim().isNotEmpty == true
          ? map['id'] as String
          : (documentId ?? ''),
      name: (map['name'] as String?) ??
          (map['title'] as String?) ??
          (map['addressHint'] as String?) ??
          '名称未設定の自販機',
      latitude: _toDouble(map['latitude'] ?? map['lat']),
      longitude: _toDouble(map['longitude'] ?? map['lng']),
      distanceMeters: _toDouble(map['distanceMeters']),
      addressHint: (map['addressHint'] as String?) ?? '',
      paymentLabel: (map['paymentLabel'] as String?) ?? _paymentLabelFromMap(map),
      updatedLabel: (map['updatedLabel'] as String?) ?? _updatedLabelFromMap(map),
      tags: ((map['tags'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      drinks: parsedDrinks,
      photoUrls: rawPhotoUrls.map((e) => e.toString()).toList(),
      reliabilityScore: _toInt(map['reliabilityScore'], fallback: 50),
      hasFavoriteMatch: (map['hasFavoriteMatch'] as bool?) ?? false,
      createdAt: _timestampToDateTime(map['createdAt']),
      updatedAt: _timestampToDateTime(map['updatedAt']),
      lastCheckedAt: _timestampToDateTime(map['lastCheckedAt']),
      checkinCount: _toInt(map['checkinCount']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'lat': latitude,
      'lng': longitude,
      'distanceMeters': distanceMeters,
      'addressHint': addressHint,
      'paymentLabel': paymentLabel,
      'updatedLabel': updatedLabel,
      'tags': tags,
      'drinks': drinks.map((e) => e.toMap()).toList(),
      'products': drinks.map((e) => e.name).toList(),
      'photoUrls': photoUrls,
      'imageUrl': photoUrls.isNotEmpty ? photoUrls.first : null,
      'reliabilityScore': reliabilityScore,
      'hasFavoriteMatch': hasFavoriteMatch,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastCheckedAt':
      lastCheckedAt != null ? Timestamp.fromDate(lastCheckedAt!) : null,
      'checkinCount': checkinCount,
    };
  }

  VendingMachine copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? distanceMeters,
    String? addressHint,
    String? paymentLabel,
    String? updatedLabel,
    List<String>? tags,
    List<DrinkItem>? drinks,
    List<String>? photoUrls,
    int? reliabilityScore,
    bool? hasFavoriteMatch,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastCheckedAt,
    int? checkinCount,
  }) {
    return VendingMachine(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      addressHint: addressHint ?? this.addressHint,
      paymentLabel: paymentLabel ?? this.paymentLabel,
      updatedLabel: updatedLabel ?? this.updatedLabel,
      tags: tags ?? this.tags,
      drinks: drinks ?? this.drinks,
      photoUrls: photoUrls ?? this.photoUrls,
      reliabilityScore: reliabilityScore ?? this.reliabilityScore,
      hasFavoriteMatch: hasFavoriteMatch ?? this.hasFavoriteMatch,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      checkinCount: checkinCount ?? this.checkinCount,
    );
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? fallback;
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<dynamic>? _photoUrlsFromSingleImage(Map<String, dynamic> map) {
    final imageUrl = map['imageUrl'];
    if (imageUrl is String && imageUrl.isNotEmpty) {
      return <String>[imageUrl];
    }
    return null;
  }

  static String _paymentLabelFromMap(Map<String, dynamic> map) {
    final tags = ((map['tags'] as List<dynamic>?) ?? const [])
        .map((e) => e.toString())
        .toList();

    if (tags.contains('電子決済OK')) return '電子決済OK';
    if (tags.contains('現金のみ')) return '現金のみ';
    return '';
  }

  static String _updatedLabelFromMap(Map<String, dynamic> map) {
    final lastCheckedAt = _timestampToDateTime(map['lastCheckedAt']);
    final updatedAt = _timestampToDateTime(map['updatedAt']);
    final target = lastCheckedAt ?? updatedAt;
    if (target == null) return '';

    final now = DateTime.now();
    final diff = now.difference(target).inDays;

    if (diff <= 0) return '今日更新';
    if (diff == 1) return '1日前に更新';
    return '$diff日前に更新';
  }
}