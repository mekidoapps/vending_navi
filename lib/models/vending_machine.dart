import 'package:cloud_firestore/cloud_firestore.dart';

class VendingMachine {
  const VendingMachine({
    required this.id,
    required this.lat,
    required this.lng,
    required this.name,
    required this.manufacturer,
    required this.products,
    required this.createdAt,
    required this.updatedAt,
    this.lastCheckedAt,
    this.checkinCount = 0,
    this.address,
    this.locationName,
    this.imageUrl,
    this.note,
    this.tags = const <String>[],
    this.cashlessSupported = false,
  });

  final String id;
  final double lat;
  final double lng;
  final String name;
  final String manufacturer;

  final List<Map<String, dynamic>> products;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastCheckedAt;
  final int checkinCount;

  final String? address;
  final String? locationName;
  final String? imageUrl;
  final String? note;
  final List<String> tags;
  final bool cashlessSupported;

  factory VendingMachine.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data =
        (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

    final dynamic createdAtTs = data['createdAt'];
    final dynamic updatedAtTs = data['updatedAt'];
    final dynamic lastCheckedAtTs = data['lastCheckedAt'];

    return VendingMachine(
      id: doc.id,
      lat: _readDouble(data['lat'] ?? data['latitude']),
      lng: _readDouble(data['lng'] ?? data['longitude']),
      name: _readNonEmptyString(data['name'], fallback: '自販機'),
      manufacturer: _readNonEmptyString(data['manufacturer'], fallback: '不明'),
      products: _readProducts(data),
      createdAt: _readDateTime(createdAtTs) ?? DateTime.now(),
      updatedAt:
      _readDateTime(updatedAtTs) ?? _readDateTime(createdAtTs) ?? DateTime.now(),
      lastCheckedAt:
      _readDateTime(lastCheckedAtTs) ?? _readDateTime(updatedAtTs),
      checkinCount: _readInt(data['checkinCount']),
      address: _readNullableString(data['address']),
      locationName: _readNullableString(data['locationName']),
      imageUrl: _readNullableString(data['imageUrl']),
      note: _readNullableString(data['note']),
      tags: _readStringList(data['tags']),
      cashlessSupported: data['cashlessSupported'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'manufacturer': manufacturer,
      'lat': lat,
      'lng': lng,
      'latitude': lat,
      'longitude': lng,
      'address': address,
      'locationName': locationName,
      'imageUrl': imageUrl,
      'note': note,
      'tags': tags,
      'cashlessSupported': cashlessSupported,
      'products': products.map(_normalizeProductMap).toList(),
      'drinkSlots': products.map(_normalizeProductMap).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastCheckedAt': Timestamp.fromDate(lastCheckedAt ?? updatedAt),
      'checkinCount': checkinCount,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  VendingMachine copyWith({
    String? id,
    double? lat,
    double? lng,
    String? name,
    String? manufacturer,
    List<Map<String, dynamic>>? products,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastCheckedAt,
    int? checkinCount,
    String? address,
    String? locationName,
    String? imageUrl,
    String? note,
    List<String>? tags,
    bool? cashlessSupported,
  }) {
    return VendingMachine(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      products: products ?? this.products,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      checkinCount: checkinCount ?? this.checkinCount,
      address: address ?? this.address,
      locationName: locationName ?? this.locationName,
      imageUrl: imageUrl ?? this.imageUrl,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      cashlessSupported: cashlessSupported ?? this.cashlessSupported,
    );
  }

  double get latitude => lat;
  double get longitude => lng;

  /// 旧名互換
  List<Map<String, dynamic>> get drinkSlots => products;

  bool get hasProducts => products.isNotEmpty;
  bool get hasLocationName => (locationName?.trim().isNotEmpty ?? false);
  bool get hasAddress => (address?.trim().isNotEmpty ?? false);
  bool get hasNote => (note?.trim().isNotEmpty ?? false);
  bool get hasImage => (imageUrl?.trim().isNotEmpty ?? false);

  List<String> get productNames {
    final List<String> result = <String>[];
    final Set<String> used = <String>{};

    for (final Map<String, dynamic> product in products) {
      final String name = _readNullableString(product['name']) ?? '';
      if (name.isEmpty) continue;

      final String key = _normalize(name);
      if (used.contains(key)) continue;

      used.add(key);
      result.add(name);
    }

    return result;
  }

  List<String> get productTags {
    final List<String> result = <String>[];
    final Set<String> used = <String>{};

    for (final Map<String, dynamic> product in products) {
      final List<String> tagList = _readStringList(product['tags']);
      for (final String tag in tagList) {
        final String trimmed = tag.trim();
        if (trimmed.isEmpty) continue;

        final String key = _normalize(trimmed);
        if (used.contains(key)) continue;

        used.add(key);
        result.add(trimmed);
      }
    }

    return result;
  }

  static List<Map<String, dynamic>> _readProducts(Map<String, dynamic> data) {
    final dynamic rawProducts = data['products'];
    if (rawProducts is List) {
      return rawProducts
          .whereType<Map>()
          .map((e) => _normalizeProductMap(Map<String, dynamic>.from(e)))
          .where((e) => (_readNullableString(e['name']) ?? '').isNotEmpty)
          .toList();
    }

    final dynamic rawDrinkSlots = data['drinkSlots'];
    if (rawDrinkSlots is List) {
      return rawDrinkSlots
          .whereType<Map>()
          .map((e) => _normalizeProductMap(Map<String, dynamic>.from(e)))
          .where((e) => (_readNullableString(e['name']) ?? '').isNotEmpty)
          .toList();
    }

    final dynamic stringProducts = data['drinks'];
    if (stringProducts is List) {
      return stringProducts
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .map(
            (name) => <String, dynamic>{
          'name': name,
          'tags': const <String>[],
        },
      )
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _normalizeProductMap(Map<String, dynamic> map) {
    return <String, dynamic>{
      'name': _readNullableString(map['name']) ?? '',
      'tags': _readStringList(map['tags']),
    };
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }

  static double _readDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static String _readNonEmptyString(
      dynamic value, {
        required String fallback,
      }) {
    final String? text = _readNullableString(value);
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _normalize(String input) {
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