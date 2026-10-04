// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionLocation {

 String get directory; String? get workspaceID;
/// Create a copy of SessionLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionLocationCopyWith<SessionLocation> get copyWith => _$SessionLocationCopyWithImpl<SessionLocation>(this as SessionLocation, _$identity);

  /// Serializes this SessionLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionLocation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionLocation&&(identical(other.directory, _this.directory) || other.directory == _this.directory)&&(identical(other.workspaceID, _this.workspaceID) || other.workspaceID == _this.workspaceID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionLocation;
  return Object.hash(runtimeType,_this.directory,_this.workspaceID);
}

@override
String toString() {
  final _this = this as SessionLocation;
  return 'SessionLocation(directory: ${_this.directory}, workspaceID: ${_this.workspaceID})';
}


}

/// @nodoc
abstract mixin class $SessionLocationCopyWith<$Res>  {
  factory $SessionLocationCopyWith(SessionLocation value, $Res Function(SessionLocation) _then) = _$SessionLocationCopyWithImpl;
@useResult
$Res call({
 String directory, String? workspaceID
});




}
/// @nodoc
class _$SessionLocationCopyWithImpl<$Res>
    implements $SessionLocationCopyWith<$Res> {
  _$SessionLocationCopyWithImpl(this._self, this._then);

  final SessionLocation _self;
  final $Res Function(SessionLocation) _then;

/// Create a copy of SessionLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? directory = null,Object? workspaceID = freezed,}) {
  return _then(SessionLocation(
directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,workspaceID: freezed == workspaceID ? _self.workspaceID : workspaceID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionLocation].
extension SessionLocationPatterns on SessionLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionLocation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionLocation value)  $default,){
final _that = this;
switch (_that) {
case _SessionLocation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionLocation value)?  $default,){
final _that = this;
switch (_that) {
case _SessionLocation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String directory,  String? workspaceID)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionLocation() when $default != null:
return $default(_that.directory,_that.workspaceID);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String directory,  String? workspaceID)  $default,) {final _that = this;
switch (_that) {
case _SessionLocation():
return $default(_that.directory,_that.workspaceID);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String directory,  String? workspaceID)?  $default,) {final _that = this;
switch (_that) {
case _SessionLocation() when $default != null:
return $default(_that.directory,_that.workspaceID);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionLocation implements SessionLocation {
  const _SessionLocation({required this.directory, this.workspaceID});
  factory _SessionLocation.fromJson(Map<String, dynamic> json) => _$SessionLocationFromJson(json);

@override final  String directory;
@override final  String? workspaceID;

/// Create a copy of SessionLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionLocationCopyWith<_SessionLocation> get copyWith => __$SessionLocationCopyWithImpl<_SessionLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionLocationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionLocation&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.workspaceID, workspaceID) || other.workspaceID == workspaceID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,directory,workspaceID);
}

@override
String toString() {
    return 'SessionLocation(directory: $directory, workspaceID: $workspaceID)';
}


}

/// @nodoc
abstract mixin class _$SessionLocationCopyWith<$Res> implements $SessionLocationCopyWith<$Res> {
  factory _$SessionLocationCopyWith(_SessionLocation value, $Res Function(_SessionLocation) _then) = __$SessionLocationCopyWithImpl;
@override @useResult
$Res call({
 String directory, String? workspaceID
});




}
/// @nodoc
class __$SessionLocationCopyWithImpl<$Res>
    implements _$SessionLocationCopyWith<$Res> {
  __$SessionLocationCopyWithImpl(this._self, this._then);

  final _SessionLocation _self;
  final $Res Function(_SessionLocation) _then;

/// Create a copy of SessionLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? directory = null,Object? workspaceID = freezed,}) {
  return _then(_SessionLocation(
directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,workspaceID: freezed == workspaceID ? _self.workspaceID : workspaceID // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SessionTime {

 double get created; double get updated; double? get archived;
/// Create a copy of SessionTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionTimeCopyWith<SessionTime> get copyWith => _$SessionTimeCopyWithImpl<SessionTime>(this as SessionTime, _$identity);

  /// Serializes this SessionTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionTime;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionTime&&(identical(other.created, _this.created) || other.created == _this.created)&&(identical(other.updated, _this.updated) || other.updated == _this.updated)&&(identical(other.archived, _this.archived) || other.archived == _this.archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionTime;
  return Object.hash(runtimeType,_this.created,_this.updated,_this.archived);
}

@override
String toString() {
  final _this = this as SessionTime;
  return 'SessionTime(created: ${_this.created}, updated: ${_this.updated}, archived: ${_this.archived})';
}


}

/// @nodoc
abstract mixin class $SessionTimeCopyWith<$Res>  {
  factory $SessionTimeCopyWith(SessionTime value, $Res Function(SessionTime) _then) = _$SessionTimeCopyWithImpl;
@useResult
$Res call({
 double created, double updated, double? archived
});




}
/// @nodoc
class _$SessionTimeCopyWithImpl<$Res>
    implements $SessionTimeCopyWith<$Res> {
  _$SessionTimeCopyWithImpl(this._self, this._then);

  final SessionTime _self;
  final $Res Function(SessionTime) _then;

/// Create a copy of SessionTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? created = null,Object? updated = null,Object? archived = freezed,}) {
  return _then(SessionTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as double,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as double,archived: freezed == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionTime].
extension SessionTimePatterns on SessionTime {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionTime value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionTime() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionTime value)  $default,){
final _that = this;
switch (_that) {
case _SessionTime():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionTime value)?  $default,){
final _that = this;
switch (_that) {
case _SessionTime() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double created,  double updated,  double? archived)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionTime() when $default != null:
return $default(_that.created,_that.updated,_that.archived);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double created,  double updated,  double? archived)  $default,) {final _that = this;
switch (_that) {
case _SessionTime():
return $default(_that.created,_that.updated,_that.archived);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double created,  double updated,  double? archived)?  $default,) {final _that = this;
switch (_that) {
case _SessionTime() when $default != null:
return $default(_that.created,_that.updated,_that.archived);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionTime implements SessionTime {
  const _SessionTime({required this.created, required this.updated, this.archived});
  factory _SessionTime.fromJson(Map<String, dynamic> json) => _$SessionTimeFromJson(json);

@override final  double created;
@override final  double updated;
@override final  double? archived;

/// Create a copy of SessionTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionTimeCopyWith<_SessionTime> get copyWith => __$SessionTimeCopyWithImpl<_SessionTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionTimeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated)&&(identical(other.archived, archived) || other.archived == archived));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,created,updated,archived);
}

@override
String toString() {
    return 'SessionTime(created: $created, updated: $updated, archived: $archived)';
}


}

/// @nodoc
abstract mixin class _$SessionTimeCopyWith<$Res> implements $SessionTimeCopyWith<$Res> {
  factory _$SessionTimeCopyWith(_SessionTime value, $Res Function(_SessionTime) _then) = __$SessionTimeCopyWithImpl;
@override @useResult
$Res call({
 double created, double updated, double? archived
});




}
/// @nodoc
class __$SessionTimeCopyWithImpl<$Res>
    implements _$SessionTimeCopyWith<$Res> {
  __$SessionTimeCopyWithImpl(this._self, this._then);

  final _SessionTime _self;
  final $Res Function(_SessionTime) _then;

/// Create a copy of SessionTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = null,Object? updated = null,Object? archived = freezed,}) {
  return _then(_SessionTime(
created: null == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as double,updated: null == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as double,archived: freezed == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$ModelRef {

 String get providerID; String get id; String? get variant;
/// Create a copy of ModelRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelRefCopyWith<ModelRef> get copyWith => _$ModelRefCopyWithImpl<ModelRef>(this as ModelRef, _$identity);

  /// Serializes this ModelRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ModelRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelRef&&(identical(other.providerID, _this.providerID) || other.providerID == _this.providerID)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.variant, _this.variant) || other.variant == _this.variant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ModelRef;
  return Object.hash(runtimeType,_this.providerID,_this.id,_this.variant);
}

@override
String toString() {
  final _this = this as ModelRef;
  return 'ModelRef(providerID: ${_this.providerID}, id: ${_this.id}, variant: ${_this.variant})';
}


}

/// @nodoc
abstract mixin class $ModelRefCopyWith<$Res>  {
  factory $ModelRefCopyWith(ModelRef value, $Res Function(ModelRef) _then) = _$ModelRefCopyWithImpl;
@useResult
$Res call({
 String providerID, String id, String? variant
});




}
/// @nodoc
class _$ModelRefCopyWithImpl<$Res>
    implements $ModelRefCopyWith<$Res> {
  _$ModelRefCopyWithImpl(this._self, this._then);

  final ModelRef _self;
  final $Res Function(ModelRef) _then;

/// Create a copy of ModelRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? providerID = null,Object? id = null,Object? variant = freezed,}) {
  return _then(ModelRef(
providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelRef].
extension ModelRefPatterns on ModelRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelRef value)  $default,){
final _that = this;
switch (_that) {
case _ModelRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelRef value)?  $default,){
final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String providerID,  String id,  String? variant)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
return $default(_that.providerID,_that.id,_that.variant);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String providerID,  String id,  String? variant)  $default,) {final _that = this;
switch (_that) {
case _ModelRef():
return $default(_that.providerID,_that.id,_that.variant);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String providerID,  String id,  String? variant)?  $default,) {final _that = this;
switch (_that) {
case _ModelRef() when $default != null:
return $default(_that.providerID,_that.id,_that.variant);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelRef extends ModelRef {
  const _ModelRef({required this.providerID, required this.id, this.variant}): super._();
  factory _ModelRef.fromJson(Map<String, dynamic> json) => _$ModelRefFromJson(json);

@override final  String providerID;
@override final  String id;
@override final  String? variant;

/// Create a copy of ModelRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelRefCopyWith<_ModelRef> get copyWith => __$ModelRefCopyWithImpl<_ModelRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelRef&&(identical(other.providerID, providerID) || other.providerID == providerID)&&(identical(other.id, id) || other.id == id)&&(identical(other.variant, variant) || other.variant == variant));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,providerID,id,variant);
}

@override
String toString() {
    return 'ModelRef(providerID: $providerID, id: $id, variant: $variant)';
}


}

/// @nodoc
abstract mixin class _$ModelRefCopyWith<$Res> implements $ModelRefCopyWith<$Res> {
  factory _$ModelRefCopyWith(_ModelRef value, $Res Function(_ModelRef) _then) = __$ModelRefCopyWithImpl;
@override @useResult
$Res call({
 String providerID, String id, String? variant
});




}
/// @nodoc
class __$ModelRefCopyWithImpl<$Res>
    implements _$ModelRefCopyWith<$Res> {
  __$ModelRefCopyWithImpl(this._self, this._then);

  final _ModelRef _self;
  final $Res Function(_ModelRef) _then;

/// Create a copy of ModelRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? providerID = null,Object? id = null,Object? variant = freezed,}) {
  return _then(_ModelRef(
providerID: null == providerID ? _self.providerID : providerID // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,variant: freezed == variant ? _self.variant : variant // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TokenUsage {

 int get input; int get output; int get reasoning; TokenCache get cache;
/// Create a copy of TokenUsage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TokenUsageCopyWith<TokenUsage> get copyWith => _$TokenUsageCopyWithImpl<TokenUsage>(this as TokenUsage, _$identity);

  /// Serializes this TokenUsage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TokenUsage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TokenUsage&&(identical(other.input, _this.input) || other.input == _this.input)&&(identical(other.output, _this.output) || other.output == _this.output)&&(identical(other.reasoning, _this.reasoning) || other.reasoning == _this.reasoning)&&(identical(other.cache, _this.cache) || other.cache == _this.cache));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TokenUsage;
  return Object.hash(runtimeType,_this.input,_this.output,_this.reasoning,_this.cache);
}

@override
String toString() {
  final _this = this as TokenUsage;
  return 'TokenUsage(input: ${_this.input}, output: ${_this.output}, reasoning: ${_this.reasoning}, cache: ${_this.cache})';
}


}

/// @nodoc
abstract mixin class $TokenUsageCopyWith<$Res>  {
  factory $TokenUsageCopyWith(TokenUsage value, $Res Function(TokenUsage) _then) = _$TokenUsageCopyWithImpl;
@useResult
$Res call({
 int input, int output, int reasoning, TokenCache cache
});


$TokenCacheCopyWith<$Res> get cache;

}
/// @nodoc
class _$TokenUsageCopyWithImpl<$Res>
    implements $TokenUsageCopyWith<$Res> {
  _$TokenUsageCopyWithImpl(this._self, this._then);

  final TokenUsage _self;
  final $Res Function(TokenUsage) _then;

/// Create a copy of TokenUsage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? input = null,Object? output = null,Object? reasoning = null,Object? cache = null,}) {
  return _then(TokenUsage(
input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as int,output: null == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as int,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as int,cache: null == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as TokenCache,
  ));
}
/// Create a copy of TokenUsage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TokenCacheCopyWith<$Res> get cache {
  
  return $TokenCacheCopyWith<$Res>(_self.cache, (value) {
    return _then(_self.copyWith(cache: value));
  });
}
}


/// Adds pattern-matching-related methods to [TokenUsage].
extension TokenUsagePatterns on TokenUsage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TokenUsage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TokenUsage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TokenUsage value)  $default,){
final _that = this;
switch (_that) {
case _TokenUsage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TokenUsage value)?  $default,){
final _that = this;
switch (_that) {
case _TokenUsage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int input,  int output,  int reasoning,  TokenCache cache)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TokenUsage() when $default != null:
return $default(_that.input,_that.output,_that.reasoning,_that.cache);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int input,  int output,  int reasoning,  TokenCache cache)  $default,) {final _that = this;
switch (_that) {
case _TokenUsage():
return $default(_that.input,_that.output,_that.reasoning,_that.cache);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int input,  int output,  int reasoning,  TokenCache cache)?  $default,) {final _that = this;
switch (_that) {
case _TokenUsage() when $default != null:
return $default(_that.input,_that.output,_that.reasoning,_that.cache);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TokenUsage extends TokenUsage {
  const _TokenUsage({this.input = 0, this.output = 0, this.reasoning = 0, this.cache = const TokenCache()}): super._();
  factory _TokenUsage.fromJson(Map<String, dynamic> json) => _$TokenUsageFromJson(json);

@override@JsonKey() final  int input;
@override@JsonKey() final  int output;
@override@JsonKey() final  int reasoning;
@override@JsonKey() final  TokenCache cache;

/// Create a copy of TokenUsage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TokenUsageCopyWith<_TokenUsage> get copyWith => __$TokenUsageCopyWithImpl<_TokenUsage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TokenUsageToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TokenUsage&&(identical(other.input, input) || other.input == input)&&(identical(other.output, output) || other.output == output)&&(identical(other.reasoning, reasoning) || other.reasoning == reasoning)&&(identical(other.cache, cache) || other.cache == cache));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,input,output,reasoning,cache);
}

@override
String toString() {
    return 'TokenUsage(input: $input, output: $output, reasoning: $reasoning, cache: $cache)';
}


}

/// @nodoc
abstract mixin class _$TokenUsageCopyWith<$Res> implements $TokenUsageCopyWith<$Res> {
  factory _$TokenUsageCopyWith(_TokenUsage value, $Res Function(_TokenUsage) _then) = __$TokenUsageCopyWithImpl;
@override @useResult
$Res call({
 int input, int output, int reasoning, TokenCache cache
});


@override $TokenCacheCopyWith<$Res> get cache;

}
/// @nodoc
class __$TokenUsageCopyWithImpl<$Res>
    implements _$TokenUsageCopyWith<$Res> {
  __$TokenUsageCopyWithImpl(this._self, this._then);

  final _TokenUsage _self;
  final $Res Function(_TokenUsage) _then;

/// Create a copy of TokenUsage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? input = null,Object? output = null,Object? reasoning = null,Object? cache = null,}) {
  return _then(_TokenUsage(
input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as int,output: null == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as int,reasoning: null == reasoning ? _self.reasoning : reasoning // ignore: cast_nullable_to_non_nullable
as int,cache: null == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as TokenCache,
  ));
}

/// Create a copy of TokenUsage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TokenCacheCopyWith<$Res> get cache {
  
  return $TokenCacheCopyWith<$Res>(_self.cache, (value) {
    return _then(_self.copyWith(cache: value));
  });
}
}


/// @nodoc
mixin _$TokenCache {

 int get read; int get write;
/// Create a copy of TokenCache
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TokenCacheCopyWith<TokenCache> get copyWith => _$TokenCacheCopyWithImpl<TokenCache>(this as TokenCache, _$identity);

  /// Serializes this TokenCache to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TokenCache;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TokenCache&&(identical(other.read, _this.read) || other.read == _this.read)&&(identical(other.write, _this.write) || other.write == _this.write));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TokenCache;
  return Object.hash(runtimeType,_this.read,_this.write);
}

@override
String toString() {
  final _this = this as TokenCache;
  return 'TokenCache(read: ${_this.read}, write: ${_this.write})';
}


}

/// @nodoc
abstract mixin class $TokenCacheCopyWith<$Res>  {
  factory $TokenCacheCopyWith(TokenCache value, $Res Function(TokenCache) _then) = _$TokenCacheCopyWithImpl;
@useResult
$Res call({
 int read, int write
});




}
/// @nodoc
class _$TokenCacheCopyWithImpl<$Res>
    implements $TokenCacheCopyWith<$Res> {
  _$TokenCacheCopyWithImpl(this._self, this._then);

  final TokenCache _self;
  final $Res Function(TokenCache) _then;

/// Create a copy of TokenCache
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? read = null,Object? write = null,}) {
  return _then(TokenCache(
read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as int,write: null == write ? _self.write : write // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TokenCache].
extension TokenCachePatterns on TokenCache {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TokenCache value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TokenCache() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TokenCache value)  $default,){
final _that = this;
switch (_that) {
case _TokenCache():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TokenCache value)?  $default,){
final _that = this;
switch (_that) {
case _TokenCache() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int read,  int write)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TokenCache() when $default != null:
return $default(_that.read,_that.write);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int read,  int write)  $default,) {final _that = this;
switch (_that) {
case _TokenCache():
return $default(_that.read,_that.write);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int read,  int write)?  $default,) {final _that = this;
switch (_that) {
case _TokenCache() when $default != null:
return $default(_that.read,_that.write);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TokenCache implements TokenCache {
  const _TokenCache({this.read = 0, this.write = 0});
  factory _TokenCache.fromJson(Map<String, dynamic> json) => _$TokenCacheFromJson(json);

@override@JsonKey() final  int read;
@override@JsonKey() final  int write;

/// Create a copy of TokenCache
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TokenCacheCopyWith<_TokenCache> get copyWith => __$TokenCacheCopyWithImpl<_TokenCache>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TokenCacheToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TokenCache&&(identical(other.read, read) || other.read == read)&&(identical(other.write, write) || other.write == write));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,read,write);
}

@override
String toString() {
    return 'TokenCache(read: $read, write: $write)';
}


}

/// @nodoc
abstract mixin class _$TokenCacheCopyWith<$Res> implements $TokenCacheCopyWith<$Res> {
  factory _$TokenCacheCopyWith(_TokenCache value, $Res Function(_TokenCache) _then) = __$TokenCacheCopyWithImpl;
@override @useResult
$Res call({
 int read, int write
});




}
/// @nodoc
class __$TokenCacheCopyWithImpl<$Res>
    implements _$TokenCacheCopyWith<$Res> {
  __$TokenCacheCopyWithImpl(this._self, this._then);

  final _TokenCache _self;
  final $Res Function(_TokenCache) _then;

/// Create a copy of TokenCache
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? read = null,Object? write = null,}) {
  return _then(_TokenCache(
read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as int,write: null == write ? _self.write : write // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SessionRevert {

 String get messageID;
/// Create a copy of SessionRevert
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionRevertCopyWith<SessionRevert> get copyWith => _$SessionRevertCopyWithImpl<SessionRevert>(this as SessionRevert, _$identity);

  /// Serializes this SessionRevert to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionRevert;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionRevert&&(identical(other.messageID, _this.messageID) || other.messageID == _this.messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionRevert;
  return Object.hash(runtimeType,_this.messageID);
}

@override
String toString() {
  final _this = this as SessionRevert;
  return 'SessionRevert(messageID: ${_this.messageID})';
}


}

/// @nodoc
abstract mixin class $SessionRevertCopyWith<$Res>  {
  factory $SessionRevertCopyWith(SessionRevert value, $Res Function(SessionRevert) _then) = _$SessionRevertCopyWithImpl;
@useResult
$Res call({
 String messageID
});




}
/// @nodoc
class _$SessionRevertCopyWithImpl<$Res>
    implements $SessionRevertCopyWith<$Res> {
  _$SessionRevertCopyWithImpl(this._self, this._then);

  final SessionRevert _self;
  final $Res Function(SessionRevert) _then;

/// Create a copy of SessionRevert
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageID = null,}) {
  return _then(SessionRevert(
messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionRevert].
extension SessionRevertPatterns on SessionRevert {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionRevert value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionRevert() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionRevert value)  $default,){
final _that = this;
switch (_that) {
case _SessionRevert():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionRevert value)?  $default,){
final _that = this;
switch (_that) {
case _SessionRevert() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageID)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionRevert() when $default != null:
return $default(_that.messageID);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageID)  $default,) {final _that = this;
switch (_that) {
case _SessionRevert():
return $default(_that.messageID);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageID)?  $default,) {final _that = this;
switch (_that) {
case _SessionRevert() when $default != null:
return $default(_that.messageID);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionRevert implements SessionRevert {
  const _SessionRevert({required this.messageID});
  factory _SessionRevert.fromJson(Map<String, dynamic> json) => _$SessionRevertFromJson(json);

@override final  String messageID;

/// Create a copy of SessionRevert
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionRevertCopyWith<_SessionRevert> get copyWith => __$SessionRevertCopyWithImpl<_SessionRevert>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionRevertToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionRevert&&(identical(other.messageID, messageID) || other.messageID == messageID));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,messageID);
}

@override
String toString() {
    return 'SessionRevert(messageID: $messageID)';
}


}

/// @nodoc
abstract mixin class _$SessionRevertCopyWith<$Res> implements $SessionRevertCopyWith<$Res> {
  factory _$SessionRevertCopyWith(_SessionRevert value, $Res Function(_SessionRevert) _then) = __$SessionRevertCopyWithImpl;
@override @useResult
$Res call({
 String messageID
});




}
/// @nodoc
class __$SessionRevertCopyWithImpl<$Res>
    implements _$SessionRevertCopyWith<$Res> {
  __$SessionRevertCopyWithImpl(this._self, this._then);

  final _SessionRevert _self;
  final $Res Function(_SessionRevert) _then;

/// Create a copy of SessionRevert
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageID = null,}) {
  return _then(_SessionRevert(
messageID: null == messageID ? _self.messageID : messageID // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Session {

 String get id; String get projectID; String? get parentID; String? get title; SessionLocation get location; SessionTime get time; String? get agent; ModelRef? get model;/// Total spend in USD across the session.
 double? get cost;/// Tokens used across the session.
 TokenUsage? get tokens;/// A staged rewind, if any.
 SessionRevert? get revert;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Session;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.projectID, _this.projectID) || other.projectID == _this.projectID)&&(identical(other.parentID, _this.parentID) || other.parentID == _this.parentID)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.location, _this.location) || other.location == _this.location)&&(identical(other.time, _this.time) || other.time == _this.time)&&(identical(other.agent, _this.agent) || other.agent == _this.agent)&&(identical(other.model, _this.model) || other.model == _this.model)&&(identical(other.cost, _this.cost) || other.cost == _this.cost)&&(identical(other.tokens, _this.tokens) || other.tokens == _this.tokens)&&(identical(other.revert, _this.revert) || other.revert == _this.revert));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Session;
  return Object.hash(runtimeType,_this.id,_this.projectID,_this.parentID,_this.title,_this.location,_this.time,_this.agent,_this.model,_this.cost,_this.tokens,_this.revert);
}

@override
String toString() {
  final _this = this as Session;
  return 'Session(id: ${_this.id}, projectID: ${_this.projectID}, parentID: ${_this.parentID}, title: ${_this.title}, location: ${_this.location}, time: ${_this.time}, agent: ${_this.agent}, model: ${_this.model}, cost: ${_this.cost}, tokens: ${_this.tokens}, revert: ${_this.revert})';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
 String id, String projectID, String? parentID, String? title, SessionLocation location, SessionTime time, String? agent, ModelRef? model, double? cost, TokenUsage? tokens, SessionRevert? revert
});


$SessionLocationCopyWith<$Res> get location;$SessionTimeCopyWith<$Res> get time;$ModelRefCopyWith<$Res>? get model;$TokenUsageCopyWith<$Res>? get tokens;$SessionRevertCopyWith<$Res>? get revert;

}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? projectID = null,Object? parentID = freezed,Object? title = freezed,Object? location = null,Object? time = null,Object? agent = freezed,Object? model = freezed,Object? cost = freezed,Object? tokens = freezed,Object? revert = freezed,}) {
  return _then(Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as SessionLocation,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as SessionTime,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ModelRef?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,tokens: freezed == tokens ? _self.tokens : tokens // ignore: cast_nullable_to_non_nullable
as TokenUsage?,revert: freezed == revert ? _self.revert : revert // ignore: cast_nullable_to_non_nullable
as SessionRevert?,
  ));
}
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionLocationCopyWith<$Res> get location {
  
  return $SessionLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTimeCopyWith<$Res> get time {
  
  return $SessionTimeCopyWith<$Res>(_self.time, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TokenUsageCopyWith<$Res>? get tokens {
    if (_self.tokens == null) {
    return null;
  }

  return $TokenUsageCopyWith<$Res>(_self.tokens!, (value) {
    return _then(_self.copyWith(tokens: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionRevertCopyWith<$Res>? get revert {
    if (_self.revert == null) {
    return null;
  }

  return $SessionRevertCopyWith<$Res>(_self.revert!, (value) {
    return _then(_self.copyWith(revert: value));
  });
}
}


/// Adds pattern-matching-related methods to [Session].
extension SessionPatterns on Session {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Session value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Session value)  $default,){
final _that = this;
switch (_that) {
case _Session():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Session value)?  $default,){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String projectID,  String? parentID,  String? title,  SessionLocation location,  SessionTime time,  String? agent,  ModelRef? model,  double? cost,  TokenUsage? tokens,  SessionRevert? revert)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.projectID,_that.parentID,_that.title,_that.location,_that.time,_that.agent,_that.model,_that.cost,_that.tokens,_that.revert);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String projectID,  String? parentID,  String? title,  SessionLocation location,  SessionTime time,  String? agent,  ModelRef? model,  double? cost,  TokenUsage? tokens,  SessionRevert? revert)  $default,) {final _that = this;
switch (_that) {
case _Session():
return $default(_that.id,_that.projectID,_that.parentID,_that.title,_that.location,_that.time,_that.agent,_that.model,_that.cost,_that.tokens,_that.revert);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String projectID,  String? parentID,  String? title,  SessionLocation location,  SessionTime time,  String? agent,  ModelRef? model,  double? cost,  TokenUsage? tokens,  SessionRevert? revert)?  $default,) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.projectID,_that.parentID,_that.title,_that.location,_that.time,_that.agent,_that.model,_that.cost,_that.tokens,_that.revert);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Session extends Session {
  const _Session({required this.id, required this.projectID, this.parentID, this.title, required this.location, required this.time, this.agent, this.model, this.cost, this.tokens, this.revert}): super._();
  factory _Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

@override final  String id;
@override final  String projectID;
@override final  String? parentID;
@override final  String? title;
@override final  SessionLocation location;
@override final  SessionTime time;
@override final  String? agent;
@override final  ModelRef? model;
/// Total spend in USD across the session.
@override final  double? cost;
/// Tokens used across the session.
@override final  TokenUsage? tokens;
/// A staged rewind, if any.
@override final  SessionRevert? revert;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.id, id) || other.id == id)&&(identical(other.projectID, projectID) || other.projectID == projectID)&&(identical(other.parentID, parentID) || other.parentID == parentID)&&(identical(other.title, title) || other.title == title)&&(identical(other.location, location) || other.location == location)&&(identical(other.time, time) || other.time == time)&&(identical(other.agent, agent) || other.agent == agent)&&(identical(other.model, model) || other.model == model)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.tokens, tokens) || other.tokens == tokens)&&(identical(other.revert, revert) || other.revert == revert));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,projectID,parentID,title,location,time,agent,model,cost,tokens,revert);
}

@override
String toString() {
    return 'Session(id: $id, projectID: $projectID, parentID: $parentID, title: $title, location: $location, time: $time, agent: $agent, model: $model, cost: $cost, tokens: $tokens, revert: $revert)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String projectID, String? parentID, String? title, SessionLocation location, SessionTime time, String? agent, ModelRef? model, double? cost, TokenUsage? tokens, SessionRevert? revert
});


@override $SessionLocationCopyWith<$Res> get location;@override $SessionTimeCopyWith<$Res> get time;@override $ModelRefCopyWith<$Res>? get model;@override $TokenUsageCopyWith<$Res>? get tokens;@override $SessionRevertCopyWith<$Res>? get revert;

}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? projectID = null,Object? parentID = freezed,Object? title = freezed,Object? location = null,Object? time = null,Object? agent = freezed,Object? model = freezed,Object? cost = freezed,Object? tokens = freezed,Object? revert = freezed,}) {
  return _then(_Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,projectID: null == projectID ? _self.projectID : projectID // ignore: cast_nullable_to_non_nullable
as String,parentID: freezed == parentID ? _self.parentID : parentID // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as SessionLocation,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as SessionTime,agent: freezed == agent ? _self.agent : agent // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as ModelRef?,cost: freezed == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double?,tokens: freezed == tokens ? _self.tokens : tokens // ignore: cast_nullable_to_non_nullable
as TokenUsage?,revert: freezed == revert ? _self.revert : revert // ignore: cast_nullable_to_non_nullable
as SessionRevert?,
  ));
}

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionLocationCopyWith<$Res> get location {
  
  return $SessionLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTimeCopyWith<$Res> get time {
  
  return $SessionTimeCopyWith<$Res>(_self.time, (value) {
    return _then(_self.copyWith(time: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelRefCopyWith<$Res>? get model {
    if (_self.model == null) {
    return null;
  }

  return $ModelRefCopyWith<$Res>(_self.model!, (value) {
    return _then(_self.copyWith(model: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TokenUsageCopyWith<$Res>? get tokens {
    if (_self.tokens == null) {
    return null;
  }

  return $TokenUsageCopyWith<$Res>(_self.tokens!, (value) {
    return _then(_self.copyWith(tokens: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionRevertCopyWith<$Res>? get revert {
    if (_self.revert == null) {
    return null;
  }

  return $SessionRevertCopyWith<$Res>(_self.revert!, (value) {
    return _then(_self.copyWith(revert: value));
  });
}
}

// dart format on
