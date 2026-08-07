import 'package:cloud_firestore/cloud_firestore.dart';

final class MachineProductIndexDto {
  const MachineProductIndexDto({
    required this.documentId,
    required this.machineId,
    required this.productId,
    required this.genreIds,
    required this.location,
    required this.geohash,
    required this.evidenceType,
    required this.availability,
    required this.isActive,
    required this.machineStatus,
    required this.machineUpdatedAt,
    required this.updatedAt,
  });

  factory MachineProductIndexDto.fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return MachineProductIndexDto(
      documentId: documentId,
      machineId: _requiredString(data, 'machineId'),
      productId: _requiredString(data, 'productId'),
      genreIds: _requiredStringList(data, 'genreIds'),
      location: _requiredGeoPoint(data, 'location'),
      geohash: _requiredString(data, 'geohash'),
      evidenceType: _requiredString(data, 'evidenceType'),
      availability: _requiredString(data, 'availability'),
      isActive: _requiredBool(data, 'isActive'),
      machineStatus: _requiredString(data, 'machineStatus'),
      machineUpdatedAt: _requiredDateTime(data, 'machineUpdatedAt'),
      updatedAt: _requiredDateTime(data, 'updatedAt'),
    );
  }

  final String documentId;
  final String machineId;
  final String productId;
  final List<String> genreIds;
  final GeoPoint location;
  final String geohash;
  final String evidenceType;
  final String availability;
  final bool isActive;
  final String machineStatus;
  final DateTime machineUpdatedAt;
  final DateTime updatedAt;
}

String _requiredString(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $field');
  }
  return value.trim();
}

List<String> _requiredStringList(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is! List) {
    throw FormatException('Missing or invalid $field');
  }

  final result = <String>[];
  for (final item in value) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('Invalid $field item');
    }
    result.add(item.trim());
  }

  return List<String>.unmodifiable(result);
}

GeoPoint _requiredGeoPoint(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is! GeoPoint) {
    throw FormatException('Missing or invalid $field');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is! bool) {
    throw FormatException('Missing or invalid $field');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> data, String field) {
  final value = data[field];

  final parsed = switch (value) {
    Timestamp timestamp => timestamp.toDate().toUtc(),
    DateTime dateTime => dateTime.toUtc(),
    String text => DateTime.tryParse(text.trim())?.toUtc(),
    _ => null,
  };

  if (parsed == null) {
    throw FormatException('Missing or invalid $field');
  }

  return parsed;
}
