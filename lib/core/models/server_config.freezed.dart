// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ServerConfig {

 String get id; String get baseUrl; String get username; String? get label;
/// Create a copy of ServerConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerConfigCopyWith<ServerConfig> get copyWith => _$ServerConfigCopyWithImpl<ServerConfig>(this as ServerConfig, _$identity);

  /// Serializes this ServerConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ServerConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerConfig&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.baseUrl, _this.baseUrl) || other.baseUrl == _this.baseUrl)&&(identical(other.username, _this.username) || other.username == _this.username)&&(identical(other.label, _this.label) || other.label == _this.label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ServerConfig;
  return Object.hash(runtimeType,_this.id,_this.baseUrl,_this.username,_this.label);
}

@override
String toString() {
  final _this = this as ServerConfig;
  return 'ServerConfig(id: ${_this.id}, baseUrl: ${_this.baseUrl}, username: ${_this.username}, label: ${_this.label})';
}


}

/// @nodoc
abstract mixin class $ServerConfigCopyWith<$Res>  {
  factory $ServerConfigCopyWith(ServerConfig value, $Res Function(ServerConfig) _then) = _$ServerConfigCopyWithImpl;
@useResult
$Res call({
 String id, String baseUrl, String username, String? label
});




}
/// @nodoc
class _$ServerConfigCopyWithImpl<$Res>
    implements $ServerConfigCopyWith<$Res> {
  _$ServerConfigCopyWithImpl(this._self, this._then);

  final ServerConfig _self;
  final $Res Function(ServerConfig) _then;

/// Create a copy of ServerConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? baseUrl = null,Object? username = null,Object? label = freezed,}) {
  return _then(ServerConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ServerConfig].
extension ServerConfigPatterns on ServerConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServerConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServerConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServerConfig value)  $default,){
final _that = this;
switch (_that) {
case _ServerConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServerConfig value)?  $default,){
final _that = this;
switch (_that) {
case _ServerConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String baseUrl,  String username,  String? label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerConfig() when $default != null:
return $default(_that.id,_that.baseUrl,_that.username,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String baseUrl,  String username,  String? label)  $default,) {final _that = this;
switch (_that) {
case _ServerConfig():
return $default(_that.id,_that.baseUrl,_that.username,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String baseUrl,  String username,  String? label)?  $default,) {final _that = this;
switch (_that) {
case _ServerConfig() when $default != null:
return $default(_that.id,_that.baseUrl,_that.username,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServerConfig extends ServerConfig {
  const _ServerConfig({required this.id, required this.baseUrl, this.username = 'opencode', this.label}): super._();
  factory _ServerConfig.fromJson(Map<String, dynamic> json) => _$ServerConfigFromJson(json);

@override final  String id;
@override final  String baseUrl;
@override@JsonKey() final  String username;
@override final  String? label;

/// Create a copy of ServerConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerConfigCopyWith<_ServerConfig> get copyWith => __$ServerConfigCopyWithImpl<_ServerConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServerConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.username, username) || other.username == username)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,baseUrl,username,label);
}

@override
String toString() {
    return 'ServerConfig(id: $id, baseUrl: $baseUrl, username: $username, label: $label)';
}


}

/// @nodoc
abstract mixin class _$ServerConfigCopyWith<$Res> implements $ServerConfigCopyWith<$Res> {
  factory _$ServerConfigCopyWith(_ServerConfig value, $Res Function(_ServerConfig) _then) = __$ServerConfigCopyWithImpl;
@override @useResult
$Res call({
 String id, String baseUrl, String username, String? label
});




}
/// @nodoc
class __$ServerConfigCopyWithImpl<$Res>
    implements _$ServerConfigCopyWith<$Res> {
  __$ServerConfigCopyWithImpl(this._self, this._then);

  final _ServerConfig _self;
  final $Res Function(_ServerConfig) _then;

/// Create a copy of ServerConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? baseUrl = null,Object? username = null,Object? label = freezed,}) {
  return _then(_ServerConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,label: freezed == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
