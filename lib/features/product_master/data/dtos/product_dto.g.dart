// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProductDto _$ProductDtoFromJson(Map<String, dynamic> json) => _ProductDto(
  documentId: json['documentId'] as String,
  name: json['name'] as String,
  manufacturerId: json['manufacturerId'] as String,
  searchKeywords:
      (json['searchKeywords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  genreIds:
      (json['genreIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  imageUrl: json['imageUrl'] as String?,
  isActive: json['isActive'] as bool? ?? true,
  createdAt: const FirestoreTimestampConverter().fromJson(json['createdAt']),
  updatedAt: const FirestoreTimestampConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$ProductDtoToJson(
  _ProductDto instance,
) => <String, dynamic>{
  'documentId': instance.documentId,
  'name': instance.name,
  'manufacturerId': instance.manufacturerId,
  'searchKeywords': instance.searchKeywords,
  'genreIds': instance.genreIds,
  'imageUrl': instance.imageUrl,
  'isActive': instance.isActive,
  'createdAt': const FirestoreTimestampConverter().toJson(instance.createdAt),
  'updatedAt': const FirestoreTimestampConverter().toJson(instance.updatedAt),
};
