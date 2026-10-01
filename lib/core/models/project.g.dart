// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectIcon _$ProjectIconFromJson(Map<String, dynamic> json) => _ProjectIcon(
  url: json['url'] as String?,
  overrideUrl: json['override'] as String?,
  color: json['color'] as String?,
);

Map<String, dynamic> _$ProjectIconToJson(_ProjectIcon instance) =>
    <String, dynamic>{
      'url': instance.url,
      'override': instance.overrideUrl,
      'color': instance.color,
    };

_ProjectTime _$ProjectTimeFromJson(Map<String, dynamic> json) => _ProjectTime(
  created: (json['created'] as num?)?.toDouble(),
  updated: (json['updated'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ProjectTimeToJson(_ProjectTime instance) =>
    <String, dynamic>{'created': instance.created, 'updated': instance.updated};

_Project _$ProjectFromJson(Map<String, dynamic> json) => _Project(
  id: json['id'] as String,
  directory: json['canonical'] as String,
  vcs: json['vcs'] as String?,
  name: json['name'] as String?,
  sandboxes:
      (json['sandboxes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  icon: json['icon'] == null
      ? null
      : ProjectIcon.fromJson(json['icon'] as Map<String, dynamic>),
  time: json['time'] == null
      ? null
      : ProjectTime.fromJson(json['time'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ProjectToJson(_Project instance) => <String, dynamic>{
  'id': instance.id,
  'canonical': instance.directory,
  'vcs': instance.vcs,
  'name': instance.name,
  'sandboxes': instance.sandboxes,
  'icon': instance.icon,
  'time': instance.time,
};
