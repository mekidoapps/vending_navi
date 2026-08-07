import 'package:cloud_firestore/cloud_firestore.dart';

final class VendingMachineDto {
  const VendingMachineDto({
    required this.documentId,
    required this.schemaVersion,
    required this.name,
    required this.manufacturerId,
    required this.manufacturerStatus,
    required this.location,
    required this.geohash,
    required this.placeDescription,
    required this.installationType,
    required this.status,
    required this.mergedIntoMachineId,
    required this.dataLevel,
    required this.primaryPhotoId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.lastProductUpdatedAt,
  });

  factory VendingMachineDto.fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return VendingMachineDto(
      documentId: documentId,
      schemaVersion: _requiredInt(data, 'schemaVersion'),
      name: _requiredString(data, 'name'),
      manufacturerId: _optionalString(data['manufacturerId']),
      manufacturerStatus: _requiredString(data, 'manufacturerStatus'),
      location: _requiredGeoPoint(data, 'location'),
      geohash: _requiredString(data, 'geohash'),
      placeDescription: _optionalString(data['placeDescription']),
      installationType: _requiredString(data, 'installationType'),
      status: _requiredString(data, 'status'),
      mergedIntoMachineId: _optionalString(data['mergedIntoMachineId']),
      dataLevel: _requiredString(data, 'dataLevel'),
      primaryPhotoId: _optionalString(data['primaryPhotoId']),
      createdBy: _requiredString(data, 'createdBy'),
      createdAt: _requiredDateTime(data, 'createdAt'),
      updatedAt: _requiredDateTime(data, 'updatedAt'),
      lastProductUpdatedAt: _optionalDateTime(data['lastProductUpdatedAt']),
    );
  }

  final String documentId;
  final int schemaVersion;
  final String name;
  final String? manufacturerId;
  final String manufacturerStatus;
  final GeoPoint location;
  final String geohash;
  final String? placeDescription;
  final String installationType;
  final String status;
  final String? mergedIntoMachineId;
  final String dataLevel;
  final String? primaryPhotoId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastProductUpdatedAt;
}

String _requiredString(Map<String, dynamic> data, String field) {
  final value = _optionalString(data[field]);
  if (value == null) {
    throw FormatException('Missing or invalid $field');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _requiredInt(Map<String, dynamic> data, String field) {
  final value = data[field];
  return switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => throw FormatException('Missing or invalid $field'),
  };
}

GeoPoint _requiredGeoPoint(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is! GeoPoint) {
    throw FormatException('Missing or invalid $field');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> data, String field) {
  final value = _optionalDateTime(data[field]);
  if (value == null) {
    throw FormatException('Missing or invalid $field');
  }
  return value;
}

DateTime? _optionalDateTime(Object? value) {
  return switch (value) {
    Timestamp timestamp => timestamp.toDate().toUtc(),
    DateTime dateTime => dateTime.toUtc(),
    String text => DateTime.tryParse(text.trim())?.toUtc(),
    _ => null,
  };
}
