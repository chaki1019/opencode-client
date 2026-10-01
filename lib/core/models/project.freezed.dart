// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProjectIcon {

 String? get url;@JsonKey(name: 'override') String? get overrideUrl; String? get color;
/// Create a copy of ProjectIcon
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectIconCopyWith<ProjectIcon> get copyWith => _$ProjectIconCopyWithImpl<ProjectIcon>(this as ProjectIcon, _$identity);

  /// Serializes this ProjectIcon to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProjectIcon;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectIcon&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.overrideUrl, _this.overrideUrl) || other.overrideUrl == _this.overrideUrl)&&(identical(other.color, _this.color) || other.color == _this.color));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProjectIcon;
  return Object.hash(runtimeType,_this.url,_this.overrideUrl,_this.color);
}

@override
String toString() {
  final _this = this as ProjectIcon;
  return 'ProjectIcon(url: ${_this.url}, overrideUrl: ${_this.overrideUrl}, color: ${_this.color})';
}


}

/// @nodoc
abstract mixin class $ProjectIconCopyWith<$Res>  {
  factory $ProjectIconCopyWith(ProjectIcon value, $Res Function(ProjectIcon) _then) = _$ProjectIconCopyWithImpl;
@useResult
$Res call({
 String? url,@JsonKey(name: 'override') String? overrideUrl, String? color
});




}
/// @nodoc
class _$ProjectIconCopyWithImpl<$Res>
    implements $ProjectIconCopyWith<$Res> {
  _$ProjectIconCopyWithImpl(this._self, this._then);

  final ProjectIcon _self;
  final $Res Function(ProjectIcon) _then;

/// Create a copy of ProjectIcon
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = freezed,Object? overrideUrl = freezed,Object? color = freezed,}) {
  return _then(ProjectIcon(
url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,overrideUrl: freezed == overrideUrl ? _self.overrideUrl : overrideUrl // ignore: cast_nullable_to_non_nullable
as String?,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectIcon].
extension ProjectIconPatterns on ProjectIcon {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectIcon value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectIcon() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectIcon value)  $default,){
final _that = this;
switch (_that) {
case _ProjectIcon():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectIcon value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectIcon() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? url, @JsonKey(name: 'override')  String? overrideUrl,  String? color)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectIcon() when $default != null:
return $default(_that.url,_that.overrideUrl,_that.color);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? url, @JsonKey(name: 'override')  String? overrideUrl,  String? color)  $default,) {final _that = this;
switch (_that) {
case _ProjectIcon():
return $default(_that.url,_that.overrideUrl,_that.color);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? url, @JsonKey(name: 'override')  String? overrideUrl,  String? color)?  $default,) {final _that = this;
switch (_that) {
case _ProjectIcon() when $default != null:
return $default(_that.url,_that.overrideUrl,_that.color);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectIcon implements ProjectIcon {
  const _ProjectIcon({this.url, @JsonKey(name: 'override') this.overrideUrl, this.color});
  factory _ProjectIcon.fromJson(Map<String, dynamic> json) => _$ProjectIconFromJson(json);

@override final  String? url;
@override@JsonKey(name: 'override') final  String? overrideUrl;
@override final  String? color;

/// Create a copy of ProjectIcon
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectIconCopyWith<_ProjectIcon> get copyWith => __$ProjectIconCopyWithImpl<_ProjectIcon>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectIconToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectIcon&&(identical(other.url, url) || other.url == url)&&(identical(other.overrideUrl, overrideUrl) || other.overrideUrl == overrideUrl)&&(identical(other.color, color) || other.color == color));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,url,overrideUrl,color);
}

@override
String toString() {
    return 'ProjectIcon(url: $url, overrideUrl: $overrideUrl, color: $color)';
}


}

/// @nodoc
abstract mixin class _$ProjectIconCopyWith<$Res> implements $ProjectIconCopyWith<$Res> {
  factory _$ProjectIconCopyWith(_ProjectIcon value, $Res Function(_ProjectIcon) _then) = __$ProjectIconCopyWithImpl;
@override @useResult
$Res call({
 String? url,@JsonKey(name: 'override') String? overrideUrl, String? color
});




}
/// @nodoc
class __$ProjectIconCopyWithImpl<$Res>
    implements _$ProjectIconCopyWith<$Res> {
  __$ProjectIconCopyWithImpl(this._self, this._then);

  final _ProjectIcon _self;
  final $Res Function(_ProjectIcon) _then;

/// Create a copy of ProjectIcon
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = freezed,Object? overrideUrl = freezed,Object? color = freezed,}) {
  return _then(_ProjectIcon(
url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,overrideUrl: freezed == overrideUrl ? _self.overrideUrl : overrideUrl // ignore: cast_nullable_to_non_nullable
as String?,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProjectTime {

 double? get created; double? get updated;
/// Create a copy of ProjectTime
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectTimeCopyWith<ProjectTime> get copyWith => _$ProjectTimeCopyWithImpl<ProjectTime>(this as ProjectTime, _$identity);

  /// Serializes this ProjectTime to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProjectTime;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectTime&&(identical(other.created, _this.created) || other.created == _this.created)&&(identical(other.updated, _this.updated) || other.updated == _this.updated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProjectTime;
  return Object.hash(runtimeType,_this.created,_this.updated);
}

@override
String toString() {
  final _this = this as ProjectTime;
  return 'ProjectTime(created: ${_this.created}, updated: ${_this.updated})';
}


}

/// @nodoc
abstract mixin class $ProjectTimeCopyWith<$Res>  {
  factory $ProjectTimeCopyWith(ProjectTime value, $Res Function(ProjectTime) _then) = _$ProjectTimeCopyWithImpl;
@useResult
$Res call({
 double? created, double? updated
});




}
/// @nodoc
class _$ProjectTimeCopyWithImpl<$Res>
    implements $ProjectTimeCopyWith<$Res> {
  _$ProjectTimeCopyWithImpl(this._self, this._then);

  final ProjectTime _self;
  final $Res Function(ProjectTime) _then;

/// Create a copy of ProjectTime
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? created = freezed,Object? updated = freezed,}) {
  return _then(ProjectTime(
created: freezed == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as double?,updated: freezed == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProjectTime].
extension ProjectTimePatterns on ProjectTime {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProjectTime value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProjectTime() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProjectTime value)  $default,){
final _that = this;
switch (_that) {
case _ProjectTime():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProjectTime value)?  $default,){
final _that = this;
switch (_that) {
case _ProjectTime() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double? created,  double? updated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProjectTime() when $default != null:
return $default(_that.created,_that.updated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double? created,  double? updated)  $default,) {final _that = this;
switch (_that) {
case _ProjectTime():
return $default(_that.created,_that.updated);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double? created,  double? updated)?  $default,) {final _that = this;
switch (_that) {
case _ProjectTime() when $default != null:
return $default(_that.created,_that.updated);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProjectTime implements ProjectTime {
  const _ProjectTime({this.created, this.updated});
  factory _ProjectTime.fromJson(Map<String, dynamic> json) => _$ProjectTimeFromJson(json);

@override final  double? created;
@override final  double? updated;

/// Create a copy of ProjectTime
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectTimeCopyWith<_ProjectTime> get copyWith => __$ProjectTimeCopyWithImpl<_ProjectTime>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectTimeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectTime&&(identical(other.created, created) || other.created == created)&&(identical(other.updated, updated) || other.updated == updated));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,created,updated);
}

@override
String toString() {
    return 'ProjectTime(created: $created, updated: $updated)';
}


}

/// @nodoc
abstract mixin class _$ProjectTimeCopyWith<$Res> implements $ProjectTimeCopyWith<$Res> {
  factory _$ProjectTimeCopyWith(_ProjectTime value, $Res Function(_ProjectTime) _then) = __$ProjectTimeCopyWithImpl;
@override @useResult
$Res call({
 double? created, double? updated
});




}
/// @nodoc
class __$ProjectTimeCopyWithImpl<$Res>
    implements _$ProjectTimeCopyWith<$Res> {
  __$ProjectTimeCopyWithImpl(this._self, this._then);

  final _ProjectTime _self;
  final $Res Function(_ProjectTime) _then;

/// Create a copy of ProjectTime
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? created = freezed,Object? updated = freezed,}) {
  return _then(_ProjectTime(
created: freezed == created ? _self.created : created // ignore: cast_nullable_to_non_nullable
as double?,updated: freezed == updated ? _self.updated : updated // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$Project {

 String get id;@JsonKey(name: 'canonical') String get directory; String? get vcs; String? get name; List<String> get sandboxes; ProjectIcon? get icon; ProjectTime? get time;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Project;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.directory, _this.directory) || other.directory == _this.directory)&&(identical(other.vcs, _this.vcs) || other.vcs == _this.vcs)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.sandboxes, _this.sandboxes)&&(identical(other.icon, _this.icon) || other.icon == _this.icon)&&(identical(other.time, _this.time) || other.time == _this.time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Project;
  return Object.hash(runtimeType,_this.id,_this.directory,_this.vcs,_this.name,const DeepCollectionEquality().hash(_this.sandboxes),_this.icon,_this.time);
}

@override
String toString() {
  final _this = this as Project;
  return 'Project(id: ${_this.id}, directory: ${_this.directory}, vcs: ${_this.vcs}, name: ${_this.name}, sandboxes: ${_this.sandboxes}, icon: ${_this.icon}, time: ${_this.time})';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'canonical') String directory, String? vcs, String? name, List<String> sandboxes, ProjectIcon? icon, ProjectTime? time
});


$ProjectIconCopyWith<$Res>? get icon;$ProjectTimeCopyWith<$Res>? get time;

}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? directory = null,Object? vcs = freezed,Object? name = freezed,Object? sandboxes = null,Object? icon = freezed,Object? time = freezed,}) {
  return _then(Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,vcs: freezed == vcs ? _self.vcs : vcs // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,sandboxes: null == sandboxes ? _self.sandboxes : sandboxes // ignore: cast_nullable_to_non_nullable
as List<String>,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as ProjectIcon?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as ProjectTime?,
  ));
}
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectIconCopyWith<$Res>? get icon {
    if (_self.icon == null) {
    return null;
  }

  return $ProjectIconCopyWith<$Res>(_self.icon!, (value) {
    return _then(_self.copyWith(icon: value));
  });
}/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $ProjectTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}


/// Adds pattern-matching-related methods to [Project].
extension ProjectPatterns on Project {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Project value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Project value)  $default,){
final _that = this;
switch (_that) {
case _Project():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Project value)?  $default,){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'canonical')  String directory,  String? vcs,  String? name,  List<String> sandboxes,  ProjectIcon? icon,  ProjectTime? time)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.directory,_that.vcs,_that.name,_that.sandboxes,_that.icon,_that.time);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'canonical')  String directory,  String? vcs,  String? name,  List<String> sandboxes,  ProjectIcon? icon,  ProjectTime? time)  $default,) {final _that = this;
switch (_that) {
case _Project():
return $default(_that.id,_that.directory,_that.vcs,_that.name,_that.sandboxes,_that.icon,_that.time);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'canonical')  String directory,  String? vcs,  String? name,  List<String> sandboxes,  ProjectIcon? icon,  ProjectTime? time)?  $default,) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.id,_that.directory,_that.vcs,_that.name,_that.sandboxes,_that.icon,_that.time);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Project extends Project {
  const _Project({required this.id, @JsonKey(name: 'canonical') required this.directory, this.vcs, this.name,  List<String> sandboxes = const <String>[], this.icon, this.time}): _sandboxes = sandboxes,super._();
  factory _Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

@override final  String id;
@override@JsonKey(name: 'canonical') final  String directory;
@override final  String? vcs;
@override final  String? name;
 final  List<String> _sandboxes;
@override@JsonKey() List<String> get sandboxes {
  if (_sandboxes is EqualUnmodifiableListView) return _sandboxes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sandboxes);
}

@override final  ProjectIcon? icon;
@override final  ProjectTime? time;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.id, id) || other.id == id)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.vcs, vcs) || other.vcs == vcs)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.sandboxes, _sandboxes)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,directory,vcs,name,const DeepCollectionEquality().hash(_sandboxes),icon,time);
}

@override
String toString() {
    return 'Project(id: $id, directory: $directory, vcs: $vcs, name: $name, sandboxes: $sandboxes, icon: $icon, time: $time)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'canonical') String directory, String? vcs, String? name, List<String> sandboxes, ProjectIcon? icon, ProjectTime? time
});


@override $ProjectIconCopyWith<$Res>? get icon;@override $ProjectTimeCopyWith<$Res>? get time;

}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? directory = null,Object? vcs = freezed,Object? name = freezed,Object? sandboxes = null,Object? icon = freezed,Object? time = freezed,}) {
  return _then(_Project(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,vcs: freezed == vcs ? _self.vcs : vcs // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,sandboxes: null == sandboxes ? _self._sandboxes : sandboxes // ignore: cast_nullable_to_non_nullable
as List<String>,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as ProjectIcon?,time: freezed == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as ProjectTime?,
  ));
}

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectIconCopyWith<$Res>? get icon {
    if (_self.icon == null) {
    return null;
  }

  return $ProjectIconCopyWith<$Res>(_self.icon!, (value) {
    return _then(_self.copyWith(icon: value));
  });
}/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProjectTimeCopyWith<$Res>? get time {
    if (_self.time == null) {
    return null;
  }

  return $ProjectTimeCopyWith<$Res>(_self.time!, (value) {
    return _then(_self.copyWith(time: value));
  });
}
}

// dart format on
