// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'v2_foundation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$V2FoundationState {

 bool get isReady; String? get message;
/// Create a copy of V2FoundationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$V2FoundationStateCopyWith<V2FoundationState> get copyWith => _$V2FoundationStateCopyWithImpl<V2FoundationState>(this as V2FoundationState, _$identity);

  /// Serializes this V2FoundationState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is V2FoundationState&&(identical(other.isReady, isReady) || other.isReady == isReady)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isReady,message);

@override
String toString() {
  return 'V2FoundationState(isReady: $isReady, message: $message)';
}


}

/// @nodoc
abstract mixin class $V2FoundationStateCopyWith<$Res>  {
  factory $V2FoundationStateCopyWith(V2FoundationState value, $Res Function(V2FoundationState) _then) = _$V2FoundationStateCopyWithImpl;
@useResult
$Res call({
 bool isReady, String? message
});




}
/// @nodoc
class _$V2FoundationStateCopyWithImpl<$Res>
    implements $V2FoundationStateCopyWith<$Res> {
  _$V2FoundationStateCopyWithImpl(this._self, this._then);

  final V2FoundationState _self;
  final $Res Function(V2FoundationState) _then;

/// Create a copy of V2FoundationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isReady = null,Object? message = freezed,}) {
  return _then(_self.copyWith(
isReady: null == isReady ? _self.isReady : isReady // ignore: cast_nullable_to_non_nullable
as bool,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [V2FoundationState].
extension V2FoundationStatePatterns on V2FoundationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _V2FoundationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _V2FoundationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _V2FoundationState value)  $default,){
final _that = this;
switch (_that) {
case _V2FoundationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _V2FoundationState value)?  $default,){
final _that = this;
switch (_that) {
case _V2FoundationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isReady,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _V2FoundationState() when $default != null:
return $default(_that.isReady,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isReady,  String? message)  $default,) {final _that = this;
switch (_that) {
case _V2FoundationState():
return $default(_that.isReady,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isReady,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _V2FoundationState() when $default != null:
return $default(_that.isReady,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _V2FoundationState implements V2FoundationState {
  const _V2FoundationState({this.isReady = false, this.message});
  factory _V2FoundationState.fromJson(Map<String, dynamic> json) => _$V2FoundationStateFromJson(json);

@override@JsonKey() final  bool isReady;
@override final  String? message;

/// Create a copy of V2FoundationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$V2FoundationStateCopyWith<_V2FoundationState> get copyWith => __$V2FoundationStateCopyWithImpl<_V2FoundationState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$V2FoundationStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _V2FoundationState&&(identical(other.isReady, isReady) || other.isReady == isReady)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isReady,message);

@override
String toString() {
  return 'V2FoundationState(isReady: $isReady, message: $message)';
}


}

/// @nodoc
abstract mixin class _$V2FoundationStateCopyWith<$Res> implements $V2FoundationStateCopyWith<$Res> {
  factory _$V2FoundationStateCopyWith(_V2FoundationState value, $Res Function(_V2FoundationState) _then) = __$V2FoundationStateCopyWithImpl;
@override @useResult
$Res call({
 bool isReady, String? message
});




}
/// @nodoc
class __$V2FoundationStateCopyWithImpl<$Res>
    implements _$V2FoundationStateCopyWith<$Res> {
  __$V2FoundationStateCopyWithImpl(this._self, this._then);

  final _V2FoundationState _self;
  final $Res Function(_V2FoundationState) _then;

/// Create a copy of V2FoundationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isReady = null,Object? message = freezed,}) {
  return _then(_V2FoundationState(
isReady: null == isReady ? _self.isReady : isReady // ignore: cast_nullable_to_non_nullable
as bool,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
