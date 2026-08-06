// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manufacturer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Manufacturer {

 ManufacturerId get id; String get name; String get displayShortName; List<String> get searchKeywords; List<ProductId> get presetProductIds; bool get isActive; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Manufacturer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ManufacturerCopyWith<Manufacturer> get copyWith => _$ManufacturerCopyWithImpl<Manufacturer>(this as Manufacturer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Manufacturer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayShortName, displayShortName) || other.displayShortName == displayShortName)&&const DeepCollectionEquality().equals(other.searchKeywords, searchKeywords)&&const DeepCollectionEquality().equals(other.presetProductIds, presetProductIds)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,displayShortName,const DeepCollectionEquality().hash(searchKeywords),const DeepCollectionEquality().hash(presetProductIds),isActive,createdAt,updatedAt);

@override
String toString() {
  return 'Manufacturer(id: $id, name: $name, displayShortName: $displayShortName, searchKeywords: $searchKeywords, presetProductIds: $presetProductIds, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ManufacturerCopyWith<$Res>  {
  factory $ManufacturerCopyWith(Manufacturer value, $Res Function(Manufacturer) _then) = _$ManufacturerCopyWithImpl;
@useResult
$Res call({
 ManufacturerId id, String name, String displayShortName, List<String> searchKeywords, List<ProductId> presetProductIds, bool isActive, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$ManufacturerCopyWithImpl<$Res>
    implements $ManufacturerCopyWith<$Res> {
  _$ManufacturerCopyWithImpl(this._self, this._then);

  final Manufacturer _self;
  final $Res Function(Manufacturer) _then;

/// Create a copy of Manufacturer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? displayShortName = null,Object? searchKeywords = null,Object? presetProductIds = null,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as ManufacturerId,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayShortName: null == displayShortName ? _self.displayShortName : displayShortName // ignore: cast_nullable_to_non_nullable
as String,searchKeywords: null == searchKeywords ? _self.searchKeywords : searchKeywords // ignore: cast_nullable_to_non_nullable
as List<String>,presetProductIds: null == presetProductIds ? _self.presetProductIds : presetProductIds // ignore: cast_nullable_to_non_nullable
as List<ProductId>,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Manufacturer].
extension ManufacturerPatterns on Manufacturer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Manufacturer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Manufacturer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Manufacturer value)  $default,){
final _that = this;
switch (_that) {
case _Manufacturer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Manufacturer value)?  $default,){
final _that = this;
switch (_that) {
case _Manufacturer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ManufacturerId id,  String name,  String displayShortName,  List<String> searchKeywords,  List<ProductId> presetProductIds,  bool isActive,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Manufacturer() when $default != null:
return $default(_that.id,_that.name,_that.displayShortName,_that.searchKeywords,_that.presetProductIds,_that.isActive,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ManufacturerId id,  String name,  String displayShortName,  List<String> searchKeywords,  List<ProductId> presetProductIds,  bool isActive,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Manufacturer():
return $default(_that.id,_that.name,_that.displayShortName,_that.searchKeywords,_that.presetProductIds,_that.isActive,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ManufacturerId id,  String name,  String displayShortName,  List<String> searchKeywords,  List<ProductId> presetProductIds,  bool isActive,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Manufacturer() when $default != null:
return $default(_that.id,_that.name,_that.displayShortName,_that.searchKeywords,_that.presetProductIds,_that.isActive,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Manufacturer extends Manufacturer {
  const _Manufacturer({required this.id, required this.name, required this.displayShortName, final  List<String> searchKeywords = const <String>[], final  List<ProductId> presetProductIds = const <ProductId>[], this.isActive = true, required this.createdAt, required this.updatedAt}): _searchKeywords = searchKeywords,_presetProductIds = presetProductIds,super._();
  

@override final  ManufacturerId id;
@override final  String name;
@override final  String displayShortName;
 final  List<String> _searchKeywords;
@override@JsonKey() List<String> get searchKeywords {
  if (_searchKeywords is EqualUnmodifiableListView) return _searchKeywords;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_searchKeywords);
}

 final  List<ProductId> _presetProductIds;
@override@JsonKey() List<ProductId> get presetProductIds {
  if (_presetProductIds is EqualUnmodifiableListView) return _presetProductIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_presetProductIds);
}

@override@JsonKey() final  bool isActive;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Manufacturer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ManufacturerCopyWith<_Manufacturer> get copyWith => __$ManufacturerCopyWithImpl<_Manufacturer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Manufacturer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayShortName, displayShortName) || other.displayShortName == displayShortName)&&const DeepCollectionEquality().equals(other._searchKeywords, _searchKeywords)&&const DeepCollectionEquality().equals(other._presetProductIds, _presetProductIds)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,displayShortName,const DeepCollectionEquality().hash(_searchKeywords),const DeepCollectionEquality().hash(_presetProductIds),isActive,createdAt,updatedAt);

@override
String toString() {
  return 'Manufacturer(id: $id, name: $name, displayShortName: $displayShortName, searchKeywords: $searchKeywords, presetProductIds: $presetProductIds, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ManufacturerCopyWith<$Res> implements $ManufacturerCopyWith<$Res> {
  factory _$ManufacturerCopyWith(_Manufacturer value, $Res Function(_Manufacturer) _then) = __$ManufacturerCopyWithImpl;
@override @useResult
$Res call({
 ManufacturerId id, String name, String displayShortName, List<String> searchKeywords, List<ProductId> presetProductIds, bool isActive, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$ManufacturerCopyWithImpl<$Res>
    implements _$ManufacturerCopyWith<$Res> {
  __$ManufacturerCopyWithImpl(this._self, this._then);

  final _Manufacturer _self;
  final $Res Function(_Manufacturer) _then;

/// Create a copy of Manufacturer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? displayShortName = null,Object? searchKeywords = null,Object? presetProductIds = null,Object? isActive = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Manufacturer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as ManufacturerId,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayShortName: null == displayShortName ? _self.displayShortName : displayShortName // ignore: cast_nullable_to_non_nullable
as String,searchKeywords: null == searchKeywords ? _self._searchKeywords : searchKeywords // ignore: cast_nullable_to_non_nullable
as List<String>,presetProductIds: null == presetProductIds ? _self._presetProductIds : presetProductIds // ignore: cast_nullable_to_non_nullable
as List<ProductId>,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
