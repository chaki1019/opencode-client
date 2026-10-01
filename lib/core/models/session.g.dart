// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionLocation _$SessionLocationFromJson(Map<String, dynamic> json) =>
    _SessionLocation(
      directory: json['directory'] as String,
      workspaceID: json['workspaceID'] as String?,
    );

Map<String, dynamic> _$SessionLocationToJson(_SessionLocation instance) =>
    <String, dynamic>{
      'directory': instance.directory,
      'workspaceID': instance.workspaceID,
    };

_SessionTime _$SessionTimeFromJson(Map<String, dynamic> json) => _SessionTime(
  created: (json['created'] as num).toDouble(),
  updated: (json['updated'] as num).toDouble(),
  archived: (json['archived'] as num?)?.toDouble(),
);

Map<String, dynamic> _$SessionTimeToJson(_SessionTime instance) =>
    <String, dynamic>{
      'created': instance.created,
      'updated': instance.updated,
      'archived': instance.archived,
    };

_ModelRef _$ModelRefFromJson(Map<String, dynamic> json) => _ModelRef(
  providerID: json['providerID'] as String,
  id: json['id'] as String,
  variant: json['variant'] as String?,
);

Map<String, dynamic> _$ModelRefToJson(_ModelRef instance) => <String, dynamic>{
  'providerID': instance.providerID,
  'id': instance.id,
  'variant': instance.variant,
};

_Session _$SessionFromJson(Map<String, dynamic> json) => _Session(
  id: json['id'] as String,
  projectID: json['projectID'] as String,
  parentID: json['parentID'] as String?,
  title: json['title'] as String?,
  location: SessionLocation.fromJson(json['location'] as Map<String, dynamic>),
  time: SessionTime.fromJson(json['time'] as Map<String, dynamic>),
  agent: json['agent'] as String?,
  model: json['model'] == null
      ? null
      : ModelRef.fromJson(json['model'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SessionToJson(_Session instance) => <String, dynamic>{
  'id': instance.id,
  'projectID': instance.projectID,
  'parentID': instance.parentID,
  'title': instance.title,
  'location': instance.location,
  'time': instance.time,
  'agent': instance.agent,
  'model': instance.model,
};
