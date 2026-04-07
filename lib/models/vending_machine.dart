import 'package:cloud_firestore/cloud_firestore.dart';

class VendingMachine {
  final String id;
  final String name;
  final String? address;

  final double latitude;
  final double longitude;

  final List<Map<String, dynamic>> drinkSlots; // 12枠ベース
  final String? imageUrl;

  final List<String> tags;
  final bool cashlessSupported;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastCheckedAt;

  final int checkinCount;

  VendingMachine({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.drinkSlots,
    this.imageUrl,
    required this.tags,
    required this.cashlessSupported,
    this.createdAt,
    this.updatedAt,
    this.lastCheckedAt,
    required this.checkinCount,
  });

  /// Firestore → Model
  factory VendingMachine.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    return VendingMachine(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'],

      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),

      drinkSlots: _parseDrinkSlots(data['drinkSlots']),

      imageUrl: data['imageUrl'],

      tags: List<String>.from(data['tags'] ?? []),
      cashlessSupported: data['cashlessSupported'] ?? false,

      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      lastCheckedAt: _toDateTime(data['lastCheckedAt']),

      checkinCount: data['checkinCount'] ?? 0,
    );
  }

  /// Model → Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'drinkSlots': drinkSlots,
      'imageUrl': imageUrl,
      'tags': tags,
      'cashlessSupported': cashlessSupported,
      'createdAt': _toTimestamp(createdAt),
      'updatedAt': _toTimestamp(updatedAt),
      'lastCheckedAt': _toTimestamp(lastCheckedAt),
      'checkinCount': checkinCount,
    };
  }

  /// copyWith
  VendingMachine copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    List<Map<String, dynamic>>? drinkSlots,
    String? imageUrl,
    List<String>? tags,
    bool? cashlessSupported,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastCheckedAt,
    int? checkinCount,
  }) {
    return VendingMachine(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      drinkSlots: drinkSlots ?? this.drinkSlots,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      cashlessSupported: cashlessSupported ?? this.cashlessSupported,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      checkinCount: checkinCount ?? this.checkinCount,
    );
  }

  /// Timestamp → DateTime
  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  /// DateTime → Timestamp
  static Timestamp? _toTimestamp(DateTime? value) {
    if (value == null) return null;
    return Timestamp.fromDate(value);
  }

  /// drinkSlots 安全パース
  static List<Map<String, dynamic>> _parseDrinkSlots(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.map<Map<String, dynamic>>((e) {
        if (e is Map<String, dynamic>) return e;
        return {};
      }).toList();
    }

    return [];
  }
}