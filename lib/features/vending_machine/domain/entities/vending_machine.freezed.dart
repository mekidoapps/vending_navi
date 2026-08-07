// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vending_machine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VendingMachine {

 VendingMachineId get id; int get schemaVersion; String get name; ManufacturerId? get manufacturerId; ManufacturerStatus get manufacturerStatus; GeoCoordinate get location;/// Required for schemaVersion=2. Nullable only while legacy documents
/// coexist with v2.
 String? get geohash; String? get placeDescription; InstallationType get installationType; VendingMachineStatus get status; VendingMachineId? get mergedIntoMachineId;/// Required for schemaVersion=2. Nullable only for legacy read data.
 VendingMachineDataLevel? get dataLevel; String? get primaryPhotoId;/// Required for schemaVersion=2. Nullable only for legacy read data.
 String? get createdBy; DateTime? get createdAt; DateTime? get updatedAt; DateTime? get lastProductUpdatedAt; List<VendingMachineProduct> get products;
/// Create a copy of VendingMachine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendingMachineCopyWith<VendingMachine> get copyWith => _$VendingMachineCopyWithImpl<VendingMachine>(this as VendingMachine, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VendingMachine&&(identical(other.id, id) || other.id == id)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.name, name) || other.name == name)&&(identical(other.manufacturerId, manufacturerId) || other.manufacturerId == manufacturerId)&&(identical(other.manufacturerStatus, manufacturerStatus) || other.manufacturerStatus == manufacturerStatus)&&(identical(other.location, location) || other.location == location)&&(identical(other.geohash, geohash) || other.geohash == geohash)&&(identical(other.placeDescription, placeDescription) || other.placeDescription == placeDescription)&&(identical(other.installationType, installationType) || other.installationType == installationType)&&(identical(other.status, status) || other.status == status)&&(identical(other.mergedIntoMachineId, mergedIntoMachineId) || other.mergedIntoMachineId == mergedIntoMachineId)&&(identical(other.dataLevel, dataLevel) || other.dataLevel == dataLevel)&&(identical(other.primaryPhotoId, primaryPhotoId) || other.primaryPhotoId == primaryPhotoId)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastProductUpdatedAt, lastProductUpdatedAt) || other.lastProductUpdatedAt == lastProductUpdatedAt)&&const DeepCollectionEquality().equals(other.products, products));
}


@override
int get hashCode => Object.hash(runtimeType,id,schemaVersion,name,manufacturerId,manufacturerStatus,location,geohash,placeDescription,installationType,status,mergedIntoMachineId,dataLevel,primaryPhotoId,createdBy,createdAt,updatedAt,lastProductUpdatedAt,const DeepCollectionEquality().hash(products));

@override
String toString() {
  return 'VendingMachine(id: $id, schemaVersion: $schemaVersion, name: $name, manufacturerId: $manufacturerId, manufacturerStatus: $manufacturerStatus, location: $location, geohash: $geohash, placeDescription: $placeDescription, installationType: $installationType, status: $status, mergedIntoMachineId: $mergedIntoMachineId, dataLevel: $dataLevel, primaryPhotoId: $primaryPhotoId, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, lastProductUpdatedAt: $lastProductUpdatedAt, products: $products)';
}


}

/// @nodoc
abstract mixin class $VendingMachineCopyWith<$Res>  {
  factory $VendingMachineCopyWith(VendingMachine value, $Res Function(VendingMachine) _then) = _$VendingMachineCopyWithImpl;
@useResult
$Res call({
 VendingMachineId id, int schemaVersion, String name, ManufacturerId? manufacturerId, ManufacturerStatus manufacturerStatus, GeoCoordinate location, String? geohash, String? placeDescription, InstallationType installationType, VendingMachineStatus status, VendingMachineId? mergedIntoMachineId, VendingMachineDataLevel? dataLevel, String? primaryPhotoId, String? createdBy, DateTime? createdAt, DateTime? updatedAt, DateTime? lastProductUpdatedAt, List<VendingMachineProduct> products
});




}
/// @nodoc
class _$VendingMachineCopyWithImpl<$Res>
    implements $VendingMachineCopyWith<$Res> {
  _$VendingMachineCopyWithImpl(this._self, this._then);

  final VendingMachine _self;
  final $Res Function(VendingMachine) _then;

/// Create a copy of VendingMachine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? schemaVersion = null,Object? name = null,Object? manufacturerId = freezed,Object? manufacturerStatus = null,Object? location = null,Object? geohash = freezed,Object? placeDescription = freezed,Object? installationType = null,Object? status = null,Object? mergedIntoMachineId = freezed,Object? dataLevel = freezed,Object? primaryPhotoId = freezed,Object? createdBy = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? lastProductUpdatedAt = freezed,Object? products = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as VendingMachineId,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,manufacturerId: freezed == manufacturerId ? _self.manufacturerId : manufacturerId // ignore: cast_nullable_to_non_nullable
as ManufacturerId?,manufacturerStatus: null == manufacturerStatus ? _self.manufacturerStatus : manufacturerStatus // ignore: cast_nullable_to_non_nullable
as ManufacturerStatus,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as GeoCoordinate,geohash: freezed == geohash ? _self.geohash : geohash // ignore: cast_nullable_to_non_nullable
as String?,placeDescription: freezed == placeDescription ? _self.placeDescription : placeDescription // ignore: cast_nullable_to_non_nullable
as String?,installationType: null == installationType ? _self.installationType : installationType // ignore: cast_nullable_to_non_nullable
as InstallationType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as VendingMachineStatus,mergedIntoMachineId: freezed == mergedIntoMachineId ? _self.mergedIntoMachineId : mergedIntoMachineId // ignore: cast_nullable_to_non_nullable
as VendingMachineId?,dataLevel: freezed == dataLevel ? _self.dataLevel : dataLevel // ignore: cast_nullable_to_non_nullable
as VendingMachineDataLevel?,primaryPhotoId: freezed == primaryPhotoId ? _self.primaryPhotoId : primaryPhotoId // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastProductUpdatedAt: freezed == lastProductUpdatedAt ? _self.lastProductUpdatedAt : lastProductUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,products: null == products ? _self.products : products // ignore: cast_nullable_to_non_nullable
as List<VendingMachineProduct>,
  ));
}

}


/// Adds pattern-matching-related methods to [VendingMachine].
extension VendingMachinePatterns on VendingMachine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VendingMachine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VendingMachine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VendingMachine value)  $default,){
final _that = this;
switch (_that) {
case _VendingMachine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VendingMachine value)?  $default,){
final _that = this;
switch (_that) {
case _VendingMachine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VendingMachineId id,  int schemaVersion,  String name,  ManufacturerId? manufacturerId,  ManufacturerStatus manufacturerStatus,  GeoCoordinate location,  String? geohash,  String? placeDescription,  InstallationType installationType,  VendingMachineStatus status,  VendingMachineId? mergedIntoMachineId,  VendingMachineDataLevel? dataLevel,  String? primaryPhotoId,  String? createdBy,  DateTime? createdAt,  DateTime? updatedAt,  DateTime? lastProductUpdatedAt,  List<VendingMachineProduct> products)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VendingMachine() when $default != null:
return $default(_that.id,_that.schemaVersion,_that.name,_that.manufacturerId,_that.manufacturerStatus,_that.location,_that.geohash,_that.placeDescription,_that.installationType,_that.status,_that.mergedIntoMachineId,_that.dataLevel,_that.primaryPhotoId,_that.createdBy,_that.createdAt,_that.updatedAt,_that.lastProductUpdatedAt,_that.products);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VendingMachineId id,  int schemaVersion,  String name,  ManufacturerId? manufacturerId,  ManufacturerStatus manufacturerStatus,  GeoCoordinate location,  String? geohash,  String? placeDescription,  InstallationType installationType,  VendingMachineStatus status,  VendingMachineId? mergedIntoMachineId,  VendingMachineDataLevel? dataLevel,  String? primaryPhotoId,  String? createdBy,  DateTime? createdAt,  DateTime? updatedAt,  DateTime? lastProductUpdatedAt,  List<VendingMachineProduct> products)  $default,) {final _that = this;
switch (_that) {
case _VendingMachine():
return $default(_that.id,_that.schemaVersion,_that.name,_that.manufacturerId,_that.manufacturerStatus,_that.location,_that.geohash,_that.placeDescription,_that.installationType,_that.status,_that.mergedIntoMachineId,_that.dataLevel,_that.primaryPhotoId,_that.createdBy,_that.createdAt,_that.updatedAt,_that.lastProductUpdatedAt,_that.products);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VendingMachineId id,  int schemaVersion,  String name,  ManufacturerId? manufacturerId,  ManufacturerStatus manufacturerStatus,  GeoCoordinate location,  String? geohash,  String? placeDescription,  InstallationType installationType,  VendingMachineStatus status,  VendingMachineId? mergedIntoMachineId,  VendingMachineDataLevel? dataLevel,  String? primaryPhotoId,  String? createdBy,  DateTime? createdAt,  DateTime? updatedAt,  DateTime? lastProductUpdatedAt,  List<VendingMachineProduct> products)?  $default,) {final _that = this;
switch (_that) {
case _VendingMachine() when $default != null:
return $default(_that.id,_that.schemaVersion,_that.name,_that.manufacturerId,_that.manufacturerStatus,_that.location,_that.geohash,_that.placeDescription,_that.installationType,_that.status,_that.mergedIntoMachineId,_that.dataLevel,_that.primaryPhotoId,_that.createdBy,_that.createdAt,_that.updatedAt,_that.lastProductUpdatedAt,_that.products);case _:
  return null;

}
}

}

/// @nodoc


class _VendingMachine extends VendingMachine {
  const _VendingMachine({required this.id, required this.schemaVersion, required this.name, this.manufacturerId, required this.manufacturerStatus, required this.location, this.geohash, this.placeDescription, required this.installationType, required this.status, this.mergedIntoMachineId, this.dataLevel, this.primaryPhotoId, this.createdBy, this.createdAt, this.updatedAt, this.lastProductUpdatedAt, final  List<VendingMachineProduct> products = const <VendingMachineProduct>[]}): _products = products,super._();
  

@override final  VendingMachineId id;
@override final  int schemaVersion;
@override final  String name;
@override final  ManufacturerId? manufacturerId;
@override final  ManufacturerStatus manufacturerStatus;
@override final  GeoCoordinate location;
/// Required for schemaVersion=2. Nullable only while legacy documents
/// coexist with v2.
@override final  String? geohash;
@override final  String? placeDescription;
@override final  InstallationType installationType;
@override final  VendingMachineStatus status;
@override final  VendingMachineId? mergedIntoMachineId;
/// Required for schemaVersion=2. Nullable only for legacy read data.
@override final  VendingMachineDataLevel? dataLevel;
@override final  String? primaryPhotoId;
/// Required for schemaVersion=2. Nullable only for legacy read data.
@override final  String? createdBy;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;
@override final  DateTime? lastProductUpdatedAt;
 final  List<VendingMachineProduct> _products;
@override@JsonKey() List<VendingMachineProduct> get products {
  if (_products is EqualUnmodifiableListView) return _products;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_products);
}


/// Create a copy of VendingMachine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendingMachineCopyWith<_VendingMachine> get copyWith => __$VendingMachineCopyWithImpl<_VendingMachine>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendingMachine&&(identical(other.id, id) || other.id == id)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.name, name) || other.name == name)&&(identical(other.manufacturerId, manufacturerId) || other.manufacturerId == manufacturerId)&&(identical(other.manufacturerStatus, manufacturerStatus) || other.manufacturerStatus == manufacturerStatus)&&(identical(other.location, location) || other.location == location)&&(identical(other.geohash, geohash) || other.geohash == geohash)&&(identical(other.placeDescription, placeDescription) || other.placeDescription == placeDescription)&&(identical(other.installationType, installationType) || other.installationType == installationType)&&(identical(other.status, status) || other.status == status)&&(identical(other.mergedIntoMachineId, mergedIntoMachineId) || other.mergedIntoMachineId == mergedIntoMachineId)&&(identical(other.dataLevel, dataLevel) || other.dataLevel == dataLevel)&&(identical(other.primaryPhotoId, primaryPhotoId) || other.primaryPhotoId == primaryPhotoId)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastProductUpdatedAt, lastProductUpdatedAt) || other.lastProductUpdatedAt == lastProductUpdatedAt)&&const DeepCollectionEquality().equals(other._products, _products));
}


@override
int get hashCode => Object.hash(runtimeType,id,schemaVersion,name,manufacturerId,manufacturerStatus,location,geohash,placeDescription,installationType,status,mergedIntoMachineId,dataLevel,primaryPhotoId,createdBy,createdAt,updatedAt,lastProductUpdatedAt,const DeepCollectionEquality().hash(_products));

@override
String toString() {
  return 'VendingMachine(id: $id, schemaVersion: $schemaVersion, name: $name, manufacturerId: $manufacturerId, manufacturerStatus: $manufacturerStatus, location: $location, geohash: $geohash, placeDescription: $placeDescription, installationType: $installationType, status: $status, mergedIntoMachineId: $mergedIntoMachineId, dataLevel: $dataLevel, primaryPhotoId: $primaryPhotoId, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, lastProductUpdatedAt: $lastProductUpdatedAt, products: $products)';
}


}

/// @nodoc
abstract mixin class _$VendingMachineCopyWith<$Res> implements $VendingMachineCopyWith<$Res> {
  factory _$VendingMachineCopyWith(_VendingMachine value, $Res Function(_VendingMachine) _then) = __$VendingMachineCopyWithImpl;
@override @useResult
$Res call({
 VendingMachineId id, int schemaVersion, String name, ManufacturerId? manufacturerId, ManufacturerStatus manufacturerStatus, GeoCoordinate location, String? geohash, String? placeDescription, InstallationType installationType, VendingMachineStatus status, VendingMachineId? mergedIntoMachineId, VendingMachineDataLevel? dataLevel, String? primaryPhotoId, String? createdBy, DateTime? createdAt, DateTime? updatedAt, DateTime? lastProductUpdatedAt, List<VendingMachineProduct> products
});




}
/// @nodoc
class __$VendingMachineCopyWithImpl<$Res>
    implements _$VendingMachineCopyWith<$Res> {
  __$VendingMachineCopyWithImpl(this._self, this._then);

  final _VendingMachine _self;
  final $Res Function(_VendingMachine) _then;

/// Create a copy of VendingMachine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? schemaVersion = null,Object? name = null,Object? manufacturerId = freezed,Object? manufacturerStatus = null,Object? location = null,Object? geohash = freezed,Object? placeDescription = freezed,Object? installationType = null,Object? status = null,Object? mergedIntoMachineId = freezed,Object? dataLevel = freezed,Object? primaryPhotoId = freezed,Object? createdBy = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? lastProductUpdatedAt = freezed,Object? products = null,}) {
  return _then(_VendingMachine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as VendingMachineId,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,manufacturerId: freezed == manufacturerId ? _self.manufacturerId : manufacturerId // ignore: cast_nullable_to_non_nullable
as ManufacturerId?,manufacturerStatus: null == manufacturerStatus ? _self.manufacturerStatus : manufacturerStatus // ignore: cast_nullable_to_non_nullable
as ManufacturerStatus,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as GeoCoordinate,geohash: freezed == geohash ? _self.geohash : geohash // ignore: cast_nullable_to_non_nullable
as String?,placeDescription: freezed == placeDescription ? _self.placeDescription : placeDescription // ignore: cast_nullable_to_non_nullable
as String?,installationType: null == installationType ? _self.installationType : installationType // ignore: cast_nullable_to_non_nullable
as InstallationType,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as VendingMachineStatus,mergedIntoMachineId: freezed == mergedIntoMachineId ? _self.mergedIntoMachineId : mergedIntoMachineId // ignore: cast_nullable_to_non_nullable
as VendingMachineId?,dataLevel: freezed == dataLevel ? _self.dataLevel : dataLevel // ignore: cast_nullable_to_non_nullable
as VendingMachineDataLevel?,primaryPhotoId: freezed == primaryPhotoId ? _self.primaryPhotoId : primaryPhotoId // ignore: cast_nullable_to_non_nullable
as String?,createdBy: freezed == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastProductUpdatedAt: freezed == lastProductUpdatedAt ? _self.lastProductUpdatedAt : lastProductUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,products: null == products ? _self._products : products // ignore: cast_nullable_to_non_nullable
as List<VendingMachineProduct>,
  ));
}


}

// dart format on
