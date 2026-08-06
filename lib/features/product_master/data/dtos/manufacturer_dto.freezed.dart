// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manufacturer_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ManufacturerDto {

 String get documentId; String get name; String get displayShortName; List<String> get searchKeywords; List<String> get presetProductIds; bool get isActive;@FirestoreTimestampConverter() DateTime get createdAt;@FirestoreTimestampConverter() DateTime get updatedAt;
/// Create a copy of ManufacturerDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManufacturerDtoCopyWith<ManufacturerDto> get copyWith => _$ManufacturerDtoCopyWithImpl<ManufacturerDto>(this as ManufacturerDto, _$identity);

  /// Serializes this ManufacturerDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ManufacturerDto&&(identical(other.documentId, documentId) || other.documentId == documentId)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayShortName, displayShortName) || other.displayShortName == displayShortName)&&const DeepCollectionEquality().equals(other.searchKeywords, searchKeywords)&&const DeepCollectionEquality().equals(other.presetProductIds, presetProductIds)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,documentId,name,displayShortName,const DeepCollectionEquality().hash(searchKeywords),const DeepCollectionEquality().hash(presetProductIds),isActive,createdAt,updatedAt);

@override
String toString() {
  return 'ManufacturerDto(documentId: $documentId, name: $name, displayShortName: $displayShortName, searchKeywords: $searchKeywords, presetProductIds: $presetProductIds, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ManufacturerDtoCopyWith<$Res>  {
  factory $ManufacturerDtoCopyWith(ManufacturerDto value, $Res Function(ManufacturerDto) _then) = _$ManufacturerDtoCopyWithImpl;
@useResult
$Res call({
 String documentId, String name, String displayShortName, List<String> searchKeywords, List<String> presetProductIds, bool isActive,@FirestoreTimestampConverter() DateTime createdAt,@FirestoreTimestampConverter() DateTime updatedAt
});




}
/// @nodoc
class _$ManufacturerDtoCopyWithImpl<$Res>
    implements $ManufacturerDtoCopyWith<$Res> {
  _$ManufacturerDtoCopyWithImpl(this._self, this._then);

  final ManufacturerDto _self;
  final $Res Function(ManufacturerDto) _then;

/// Create a copy of ManufacturerDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? documentId = null,Object? name = null,Object? displayShortName = null,Object? searchKeywords = null,Object? presetProductIds = null,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
documentId: null == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayShortName: null == displayShortName ? _self.displayShortName : displayShortName // ignore: cast_nullable_to_non_nullable
as String,searchKeywords: null == searchKeywords ? _self.searchKeywords : searchKeywords // ignore: cast_nullable_to_non_nullable
as List<String>,presetProductIds: null == presetProductIds ? _self.presetProductIds : presetProductIds // ignore: cast_nullable_to_non_nullable
as List<String>,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ManufacturerDto].
extension ManufacturerDtoPatterns on ManufacturerDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ManufacturerDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ManufacturerDto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ManufacturerDto value)  $default,){
final _that = this;
switch (_that) {
case _ManufacturerDto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ManufacturerDto value)?  $default,){
final _that = this;
switch (_that) {
case _ManufacturerDto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String documentId,  String name,  String displayShortName,  List<String> searchKeywords,  List<String> presetProductIds,  bool isActive, @FirestoreTimestampConverter()  DateTime createdAt, @FirestoreTimestampConverter()  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ManufacturerDto() when $default != null:
return $default(_that.documentId,_that.name,_that.displayShortName,_that.searchKeywords,_that.presetProductIds,_that.isActive,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String documentId,  String name,  String displayShortName,  List<String> searchKeywords,  List<String> presetProductIds,  bool isActive, @FirestoreTimestampConverter()  DateTime createdAt, @FirestoreTimestampConverter()  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ManufacturerDto():
return $default(_that.documentId,_that.name,_that.displayShortName,_that.searchKeywords,_that.presetProductIds,_that.isActive,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String documentId,  String name,  String displayShortName,  List<String> searchKeywords,  List<String> presetProductIds,  bool isActive, @FirestoreTimestampConverter()  DateTime createdAt, @FirestoreTimestampConverter()  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ManufacturerDto() when $default != null:
return $default(_that.documentId,_that.name,_that.displayShortName,_that.searchKeywords,_that.presetProductIds,_that.isActive,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ManufacturerDto extends ManufacturerDto {
  const _ManufacturerDto({required this.documentId, required this.name, required this.displayShortName, final  List<String> searchKeywords = const <String>[], final  List<String> presetProductIds = const <String>[], this.isActive = true, @FirestoreTimestampConverter() required this.createdAt, @FirestoreTimestampConverter() required this.updatedAt}): _searchKeywords = searchKeywords,_presetProductIds = presetProductIds,super._();
  factory _ManufacturerDto.fromJson(Map<String, dynamic> json) => _$ManufacturerDtoFromJson(json);

@override final  String documentId;
@override final  String name;
@override final  String displayShortName;
 final  List<String> _searchKeywords;
@override@JsonKey() List<String> get searchKeywords {
  if (_searchKeywords is EqualUnmodifiableListView) return _searchKeywords;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_searchKeywords);
}

 final  List<String> _presetProductIds;
@override@JsonKey() List<String> get presetProductIds {
  if (_presetProductIds is EqualUnmodifiableListView) return _presetProductIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_presetProductIds);
}

@override@JsonKey() final  bool isActive;
@override@FirestoreTimestampConverter() final  DateTime createdAt;
@override@FirestoreTimestampConverter() final  DateTime updatedAt;

/// Create a copy of ManufacturerDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManufacturerDtoCopyWith<_ManufacturerDto> get copyWith => __$ManufacturerDtoCopyWithImpl<_ManufacturerDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ManufacturerDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ManufacturerDto&&(identical(other.documentId, documentId) || other.documentId == documentId)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayShortName, displayShortName) || other.displayShortName == displayShortName)&&const DeepCollectionEquality().equals(other._searchKeywords, _searchKeywords)&&const DeepCollectionEquality().equals(other._presetProductIds, _presetProductIds)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,documentId,name,displayShortName,const DeepCollectionEquality().hash(_searchKeywords),const DeepCollectionEquality().hash(_presetProductIds),isActive,createdAt,updatedAt);

@override
String toString() {
  return 'ManufacturerDto(documentId: $documentId, name: $name, displayShortName: $displayShortName, searchKeywords: $searchKeywords, presetProductIds: $presetProductIds, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ManufacturerDtoCopyWith<$Res> implements $ManufacturerDtoCopyWith<$Res> {
  factory _$ManufacturerDtoCopyWith(_ManufacturerDto value, $Res Function(_ManufacturerDto) _then) = __$ManufacturerDtoCopyWithImpl;
@override @useResult
$Res call({
 String documentId, String name, String displayShortName, List<String> searchKeywords, List<String> presetProductIds, bool isActive,@FirestoreTimestampConverter() DateTime createdAt,@FirestoreTimestampConverter() DateTime updatedAt
});




}
/// @nodoc
class __$ManufacturerDtoCopyWithImpl<$Res>
    implements _$ManufacturerDtoCopyWith<$Res> {
  __$ManufacturerDtoCopyWithImpl(this._self, this._then);

  final _ManufacturerDto _self;
  final $Res Function(_ManufacturerDto) _then;

/// Create a copy of ManufacturerDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? documentId = null,Object? name = null,Object? displayShortName = null,Object? searchKeywords = null,Object? presetProductIds = null,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_ManufacturerDto(
documentId: null == documentId ? _self.documentId : documentId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayShortName: null == displayShortName ? _self.displayShortName : displayShortName // ignore: cast_nullable_to_non_nullable
as String,searchKeywords: null == searchKeywords ? _self._searchKeywords : searchKeywords // ignore: cast_nullable_to_non_nullable
as List<String>,presetProductIds: null == presetProductIds ? _self._presetProductIds : presetProductIds // ignore: cast_nullable_to_non_nullable
as List<String>,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
