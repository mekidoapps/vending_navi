import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// Converts Firestore timestamps at the DTO boundary.
///
/// Domain models only receive UTC [DateTime] values and do not depend on the
/// Firestore SDK.
class FirestoreTimestampConverter implements JsonConverter<DateTime, Object?> {
  const FirestoreTimestampConverter();

  @override
  DateTime fromJson(Object? value) {
    return switch (value) {
      Timestamp timestamp => timestamp.toDate().toUtc(),
      DateTime dateTime => dateTime.toUtc(),
      _ => throw FormatException('Expected Firestore Timestamp or DateTime.'),
    };
  }

  @override
  Object toJson(DateTime value) {
    return Timestamp.fromDate(value.toUtc());
  }
}
