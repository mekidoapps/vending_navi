import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vending_app/features/product_master/data/dtos/firestore_timestamp_converter.dart';

void main() {
  const converter = FirestoreTimestampConverter();

  test('TimestampをUTC DateTimeへ変換する', () {
    final source = DateTime.parse('2026-08-06T12:34:56+09:00');

    final result = converter.fromJson(Timestamp.fromDate(source));

    expect(result.isUtc, isTrue);
    expect(result, source.toUtc());
  });

  test('DateTimeをFirestore Timestampへ変換する', () {
    final source = DateTime.parse('2026-08-06T12:34:56+09:00');

    final result = converter.toJson(source);

    expect(result, isA<Timestamp>());
    expect((result as Timestamp).toDate().toUtc(), source.toUtc());
  });

  test('TimestampでもDateTimeでもない値は拒否する', () {
    expect(
      () => converter.fromJson('2026-08-06T00:00:00Z'),
      throwsA(isA<FormatException>()),
    );
  });
}
