import 'package:cloud_firestore/cloud_firestore.dart';

final class VendingMachineProductDto {
  const VendingMachineProductDto({
    required this.documentId,
    required this.productId,
    required this.evidenceType,
    required this.availability,
    required this.isActive,
    required this.confirmedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendingMachineProductDto.fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return VendingMachineProductDto(
      documentId: documentId,
      productId: _requiredString(data, 'productId'),
      evidenceType: _requiredString(data, 'evidenceType'),
      availability: _requiredString(data, 'availability'),
      isActive: _requiredBool(data, 'isActive'),
      confirmedAt: _optionalDateTime(data['confirmedAt']),
      createdAt: _requiredDateTime(data, 'createdAt'),
      updatedAt: _requiredDateTime(data, 'updatedAt'),
    );
  }

  final String documentId;
  final String productId;
  final String evidenceType;
  final String availability;
  final bool isActive;
  final DateTime? confirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
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

bool _requiredBool(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is! bool) {
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
