import 'package:freezed_annotation/freezed_annotation.dart';

import 'firestore_timestamp_converter.dart';

part 'manufacturer_dto.freezed.dart';
part 'manufacturer_dto.g.dart';

@freezed
abstract class ManufacturerDto with _$ManufacturerDto {
  const ManufacturerDto._();

  const factory ManufacturerDto({
    required String documentId,
    required String name,
    required String displayShortName,
    @Default(<String>[]) List<String> searchKeywords,
    @Default(<String>[]) List<String> presetProductIds,
    @Default(true) bool isActive,
    @FirestoreTimestampConverter() required DateTime createdAt,
    @FirestoreTimestampConverter() required DateTime updatedAt,
  }) = _ManufacturerDto;

  factory ManufacturerDto.fromJson(Map<String, dynamic> json) =>
      _$ManufacturerDtoFromJson(json);

  static ManufacturerDto fromFirestoreDocument({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    return ManufacturerDto.fromJson(<String, dynamic>{
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
