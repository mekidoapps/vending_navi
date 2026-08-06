import 'package:freezed_annotation/freezed_annotation.dart';

import 'firestore_timestamp_converter.dart';

part 'product_dto.freezed.dart';
part 'product_dto.g.dart';

@freezed
abstract class ProductDto with _$ProductDto {
  const ProductDto._();

  const factory ProductDto({
    required String documentId,
    required String name,
    required String manufacturerId,
    @Default(<String>[]) List<String> searchKeywords,
    @Default(<String>[]) List<String> genreIds,
    String? imageUrl,
    @Default(true) bool isActive,
    @FirestoreTimestampConverter() required DateTime createdAt,
    @FirestoreTimestampConverter() required DateTime updatedAt,
  }) = _ProductDto;

  factory ProductDto.fromJson(Map<String, dynamic> json) =>
      _$ProductDtoFromJson(json);

  static ProductDto fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return ProductDto.fromJson(<String, dynamic>{
      ...data,
      'documentId': documentId,
    });
  }

  /// Firestore document data without the document ID.
  ///
  /// Public writes remain Functions-only. This is provided for fixtures,
  /// migration tooling, and round-trip tests rather than direct client writes.
  Map<String, dynamic> toFirestoreData() {
    final json = Map<String, dynamic>.from(toJson());
    json.remove('documentId');
    return json;
  }
}
