// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vending_machine_product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VendingMachineProduct {

 ProductId get productId;/// Null is reserved for legacy read compatibility.
///
/// Every schemaVersion=2 Firestore product document must have a valid
/// evidence type.
 ProductEvidenceType? get evidenceType; ProductAvailability get availability; bool get isActive; String? get confirmedBy; DateTime? get confirmedAt; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of VendingMachineProduct
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendingMachineProductCopyWith<VendingMachineProduct> get copyWith => _$VendingMachineProductCopyWithImpl<VendingMachineProduct>(this as VendingMachineProduct, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VendingMachineProduct&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.evidenceType, evidenceType) || other.evidenceType == evidenceType)&&(identical(other.availability, availability) || other.availability == availability)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.confirmedBy, confirmedBy) || other.confirmedBy == confirmedBy)&&(identical(other.confirmedAt, confirmedAt) || other.confirmedAt == confirmedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,productId,evidenceType,availability,isActive,confirmedBy,confirmedAt,createdAt,updatedAt);

@override
String toString() {
  return 'VendingMachineProduct(productId: $productId, evidenceType: $evidenceType, availability: $availability, isActive: $isActive, confirmedBy: $confirmedBy, confirmedAt: $confirmedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $VendingMachineProductCopyWith<$Res>  {
  factory $VendingMachineProductCopyWith(VendingMachineProduct value, $Res Function(VendingMachineProduct) _then) = _$VendingMachineProductCopyWithImpl;
@useResult
$Res call({
 ProductId productId, ProductEvidenceType? evidenceType, ProductAvailability availability, bool isActive, String? confirmedBy, DateTime? confirmedAt, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$VendingMachineProductCopyWithImpl<$Res>
    implements $VendingMachineProductCopyWith<$Res> {
  _$VendingMachineProductCopyWithImpl(this._self, this._then);

  final VendingMachineProduct _self;
  final $Res Function(VendingMachineProduct) _then;

/// Create a copy of VendingMachineProduct
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productId = null,Object? evidenceType = freezed,Object? availability = null,Object? isActive = null,Object? confirmedBy = freezed,Object? confirmedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as ProductId,evidenceType: freezed == evidenceType ? _self.evidenceType : evidenceType // ignore: cast_nullable_to_non_nullable
as ProductEvidenceType?,availability: null == availability ? _self.availability : availability // ignore: cast_nullable_to_non_nullable
as ProductAvailability,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,confirmedBy: freezed == confirmedBy ? _self.confirmedBy : confirmedBy // ignore: cast_nullable_to_non_nullable
as String?,confirmedAt: freezed == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [VendingMachineProduct].
extension VendingMachineProductPatterns on VendingMachineProduct {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VendingMachineProduct value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VendingMachineProduct() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VendingMachineProduct value)  $default,){
final _that = this;
switch (_that) {
case _VendingMachineProduct():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VendingMachineProduct value)?  $default,){
final _that = this;
switch (_that) {
case _VendingMachineProduct() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProductId productId,  ProductEvidenceType? evidenceType,  ProductAvailability availability,  bool isActive,  String? confirmedBy,  DateTime? confirmedAt,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VendingMachineProduct() when $default != null:
return $default(_that.productId,_that.evidenceType,_that.availability,_that.isActive,_that.confirmedBy,_that.confirmedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProductId productId,  ProductEvidenceType? evidenceType,  ProductAvailability availability,  bool isActive,  String? confirmedBy,  DateTime? confirmedAt,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _VendingMachineProduct():
return $default(_that.productId,_that.evidenceType,_that.availability,_that.isActive,_that.confirmedBy,_that.confirmedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProductId productId,  ProductEvidenceType? evidenceType,  ProductAvailability availability,  bool isActive,  String? confirmedBy,  DateTime? confirmedAt,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _VendingMachineProduct() when $default != null:
return $default(_that.productId,_that.evidenceType,_that.availability,_that.isActive,_that.confirmedBy,_that.confirmedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _VendingMachineProduct extends VendingMachineProduct {
  const _VendingMachineProduct({required this.productId, this.evidenceType, required this.availability, this.isActive = true, this.confirmedBy, this.confirmedAt, this.createdAt, this.updatedAt}): super._();
  

@override final  ProductId productId;
/// Null is reserved for legacy read compatibility.
///
/// Every schemaVersion=2 Firestore product document must have a valid
/// evidence type.
@override final  ProductEvidenceType? evidenceType;
@override final  ProductAvailability availability;
@override@JsonKey() final  bool isActive;
@override final  String? confirmedBy;
@override final  DateTime? confirmedAt;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of VendingMachineProduct
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendingMachineProductCopyWith<_VendingMachineProduct> get copyWith => __$VendingMachineProductCopyWithImpl<_VendingMachineProduct>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendingMachineProduct&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.evidenceType, evidenceType) || other.evidenceType == evidenceType)&&(identical(other.availability, availability) || other.availability == availability)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.confirmedBy, confirmedBy) || other.confirmedBy == confirmedBy)&&(identical(other.confirmedAt, confirmedAt) || other.confirmedAt == confirmedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode => Object.hash(runtimeType,productId,evidenceType,availability,isActive,confirmedBy,confirmedAt,createdAt,updatedAt);

@override
String toString() {
  return 'VendingMachineProduct(productId: $productId, evidenceType: $evidenceType, availability: $availability, isActive: $isActive, confirmedBy: $confirmedBy, confirmedAt: $confirmedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$VendingMachineProductCopyWith<$Res> implements $VendingMachineProductCopyWith<$Res> {
  factory _$VendingMachineProductCopyWith(_VendingMachineProduct value, $Res Function(_VendingMachineProduct) _then) = __$VendingMachineProductCopyWithImpl;
@override @useResult
$Res call({
 ProductId productId, ProductEvidenceType? evidenceType, ProductAvailability availability, bool isActive, String? confirmedBy, DateTime? confirmedAt, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$VendingMachineProductCopyWithImpl<$Res>
    implements _$VendingMachineProductCopyWith<$Res> {
  __$VendingMachineProductCopyWithImpl(this._self, this._then);

  final _VendingMachineProduct _self;
  final $Res Function(_VendingMachineProduct) _then;

/// Create a copy of VendingMachineProduct
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productId = null,Object? evidenceType = freezed,Object? availability = null,Object? isActive = null,Object? confirmedBy = freezed,Object? confirmedAt = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_VendingMachineProduct(
productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as ProductId,evidenceType: freezed == evidenceType ? _self.evidenceType : evidenceType // ignore: cast_nullable_to_non_nullable
as ProductEvidenceType?,availability: null == availability ? _self.availability : availability // ignore: cast_nullable_to_non_nullable
as ProductAvailability,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,confirmedBy: freezed == confirmedBy ? _self.confirmedBy : confirmedBy // ignore: cast_nullable_to_non_nullable
as String?,confirmedAt: freezed == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
