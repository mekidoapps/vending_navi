import 'package:cloud_firestore/cloud_firestore.dart';

class VendingMachine {
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

  factory VendingMachine.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

    final createdAtTs = data['createdAt'] as Timestamp?;
    final updatedAtTs =
        (data['updatedAt'] as Timestamp?) ?? (data['createdAt'] as Timestamp?);
    final lastCheckedAtTs =
        (data['lastCheckedAt'] as Timestamp?) ??
            (data['updatedAt'] as Timestamp?);

    return VendingMachine(
      id: doc.id,
      lat: _readDouble(data['lat'] ?? data['latitude']),
      lng: _readDouble(data['lng'] ?? data['longitude']),
      name: (data['name'] ?? '自販機').toString(),
      manufacturer: (data['manufacturer'] ?? '不明').toString(),
      products: _readProducts(data),
      createdAt: createdAtTs?.toDate() ?? DateTime.now(),
      updatedAt: updatedAtTs?.toDate() ?? DateTime.now(),
      lastCheckedAt: lastCheckedAtTs?.toDate(),
      checkinCount: _readInt(data['checkinCount']),
      address: _readNullableString(data['address']),
      locationName: _readNullableString(data['locationName']),
      imageUrl: _readNullableString(data['imageUrl']),
      note: _readNullableString(data['note']),
      tags: _readStringList(data['tags']),
      cashlessSupported: data['cashlessSupported'] == true,
    );
  }

  static double _readDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
  }

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> _readProducts(Map<String, dynamic> data) {
    final rawProducts = data['products'];

    if (rawProducts is List) {
      return rawProducts
          .whereType<Map>()
          .map((e) {
        final map = Map<String, dynamic>.from(e);
        return <String, dynamic>{
          'name': (map['name'] ?? '').toString(),
          'tags': _readStringList(map['tags']),
        };
      })
          .where((e) => (e['name'] as String).trim().isNotEmpty)
          .toList();
    }

    final rawDrinkSlots = data['drinkSlots'];
    if (rawDrinkSlots is List) {
      return rawDrinkSlots
          .whereType<Map>()
          .map((e) {
        final map = Map<String, dynamic>.from(e);
        return <String, dynamic>{
          'name': (map['name'] ?? '').toString(),
          'tags': _readStringList(map['tags']),
        };
      })
          .where((e) => (e['name'] as String).trim().isNotEmpty)
          .toList();
    }

    return <Map<String, dynamic>>[];
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
      'products': products,
      'drinkSlots': products,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastCheckedAt': Timestamp.fromDate(lastCheckedAt ?? updatedAt),
      'checkinCount': checkinCount,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toMap();
  }

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
  List<Map<String, dynamic>> get drinkSlots => products;
}