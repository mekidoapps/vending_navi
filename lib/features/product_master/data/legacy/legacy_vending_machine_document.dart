import 'package:cloud_firestore/cloud_firestore.dart';

import 'legacy_product_candidate.dart';

/// Read-only representation of the mixed v1 vending-machine document shape.
///
/// This type intentionally preserves nullable legacy values. It must not be
/// used for new writes.
final class LegacyVendingMachineDocument {
  const LegacyVendingMachineDocument({
    required this.documentId,
    required this.schemaVersion,
    required this.name,
    required this.manufacturer,
    required this.latitude,
    required this.longitude,
    required this.products,
    required this.createdAt,
    required this.updatedAt,
    required this.lastCheckedAt,
    required this.address,
    required this.locationName,
    required this.imageUrl,
    required this.note,
    required this.tags,
    required this.cashlessSupported,
  });

  factory LegacyVendingMachineDocument.fromDocumentData({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final location = data['location'];

    return LegacyVendingMachineDocument(
      documentId: documentId.trim(),
      schemaVersion: _readInt(data['schemaVersion']) ?? 1,
      name: _readString(data['name']) ?? '自販機',
      manufacturer: _readString(data['manufacturer']),
      latitude:
          _readDouble(data['lat'] ?? data['latitude']) ??
          (location is GeoPoint ? location.latitude : null),
      longitude:
          _readDouble(data['lng'] ?? data['longitude']) ??
          (location is GeoPoint ? location.longitude : null),
      products: _readProducts(data),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt:
          _readDateTime(data['updatedAt']) ?? _readDateTime(data['createdAt']),
      lastCheckedAt:
          _readDateTime(data['lastCheckedAt']) ??
          _readDateTime(data['updatedAt']),
      address: _readString(data['address']),
      locationName: _readString(data['locationName']),
      imageUrl: _readString(data['imageUrl']),
      note: _readString(data['note']),
      tags: _readStringList(data['tags']),
      cashlessSupported: data['cashlessSupported'] == true,
    );
  }

  final String documentId;
  final int schemaVersion;
  final String name;
  final String? manufacturer;
  final double? latitude;
  final double? longitude;
  final List<LegacyProductCandidate> products;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastCheckedAt;
  final String? address;
  final String? locationName;
  final String? imageUrl;
  final String? note;
  final List<String> tags;
  final bool cashlessSupported;

  bool get isLegacySchema => schemaVersion < 2;

  static List<LegacyProductCandidate> _readProducts(Map<String, dynamic> data) {
    const sources = <(String, LegacyProductSource)>[
      ('products', LegacyProductSource.products),
      ('drinkSlots', LegacyProductSource.drinkSlots),
      ('slots', LegacyProductSource.slots),
      ('drinks', LegacyProductSource.drinks),
    ];

    for (final (field, source) in sources) {
      final raw = data[field];
      if (raw is! List) {
        continue;
      }

      final candidates = raw
          .map((value) => _readCandidate(value, source))
          .whereType<LegacyProductCandidate>()
          .toList(growable: false);
      if (candidates.isNotEmpty) {
        return List<LegacyProductCandidate>.unmodifiable(candidates);
      }
    }

    return const <LegacyProductCandidate>[];
  }

  static LegacyProductCandidate? _readCandidate(
    Object? value,
    LegacyProductSource source,
  ) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final explicitId = _readString(map['productId'] ?? map['id']);
      final name = _readString(
        map['name'] ?? map['drinkName'] ?? map['productName'],
      );
      final displayName = name ?? explicitId;
      if (displayName == null) {
        return null;
      }

      return LegacyProductCandidate(
        rawName: displayName,
        explicitProductId: explicitId,
        tags: _readStringList(map['tags']),
        isSoldOut: map['isSoldOut'] == true || map['soldOut'] == true,
        source: source,
      );
    }

    final name = _readString(value);
    if (name == null) {
      return null;
    }

    return LegacyProductCandidate(rawName: name, source: source);
  }

  static DateTime? _readDateTime(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate().toUtc(),
      DateTime dateTime => dateTime.toUtc(),
      String text => DateTime.tryParse(text.trim())?.toUtc(),
      _ => null,
    };
  }

  static double? _readDouble(Object? value) {
    return switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text.trim()),
      _ => null,
    };
  }

  static int? _readInt(Object? value) {
    return switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
  }

  static String? _readString(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    final seen = <String>{};
    final result = <String>[];
    for (final item in value) {
      final text = _readString(item);
      if (text != null && seen.add(text)) {
        result.add(text);
      }
    }
    return List<String>.unmodifiable(result);
  }
}
