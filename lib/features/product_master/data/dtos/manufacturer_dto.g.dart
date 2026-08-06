// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manufacturer_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ManufacturerDto _$ManufacturerDtoFromJson(
  Map<String, dynamic> json,
) => _ManufacturerDto(
  documentId: json['documentId'] as String,
  name: json['name'] as String,
  displayShortName: json['displayShortName'] as String,
  searchKeywords:
      (json['searchKeywords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  presetProductIds:
      (json['presetProductIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  isActive: json['isActive'] as bool? ?? true,
  createdAt: const FirestoreTimestampConverter().fromJson(json['createdAt']),
  updatedAt: const FirestoreTimestampConverter().fromJson(json['updatedAt']),
);

Map<String, dynamic> _$ManufacturerDtoToJson(
  _ManufacturerDto instance,
) => <String, dynamic>{
  'documentId': instance.documentId,
  'name': instance.name,
  'displayShortName': instance.displayShortName,
  'searchKeywords': instance.searchKeywords,
  'presetProductIds': instance.presetProductIds,
  'isActive': instance.isActive,
  'createdAt': const FirestoreTimestampConverter().toJson(instance.createdAt),
  'updatedAt': const FirestoreTimestampConverter().toJson(instance.updatedAt),
};
