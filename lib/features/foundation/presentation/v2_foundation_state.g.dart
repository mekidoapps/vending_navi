// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'v2_foundation_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_V2FoundationState _$V2FoundationStateFromJson(Map<String, dynamic> json) =>
    _V2FoundationState(
      isReady: json['isReady'] as bool? ?? false,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$V2FoundationStateToJson(_V2FoundationState instance) =>
    <String, dynamic>{'isReady': instance.isReady, 'message': instance.message};
