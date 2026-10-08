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
  idle: (json['idle'] as num?)?.toDouble(),
  viewed: (json['viewed'] as num?)?.toDouble(),
);

Map<String, dynamic> _$SessionTimeToJson(_SessionTime instance) =>
    <String, dynamic>{
      'created': instance.created,
      'updated': instance.updated,
      'archived': instance.archived,
      'idle': instance.idle,
      'viewed': instance.viewed,
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

_TokenUsage _$TokenUsageFromJson(Map<String, dynamic> json) => _TokenUsage(
  input: (json['input'] as num?)?.toInt() ?? 0,
  output: (json['output'] as num?)?.toInt() ?? 0,
  reasoning: (json['reasoning'] as num?)?.toInt() ?? 0,
  cache: json['cache'] == null
      ? const TokenCache()
      : TokenCache.fromJson(json['cache'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TokenUsageToJson(_TokenUsage instance) =>
    <String, dynamic>{
      'input': instance.input,
      'output': instance.output,
      'reasoning': instance.reasoning,
      'cache': instance.cache,
    };

_TokenCache _$TokenCacheFromJson(Map<String, dynamic> json) => _TokenCache(
  read: (json['read'] as num?)?.toInt() ?? 0,
  write: (json['write'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TokenCacheToJson(_TokenCache instance) =>
    <String, dynamic>{'read': instance.read, 'write': instance.write};

_SessionRevert _$SessionRevertFromJson(Map<String, dynamic> json) =>
    _SessionRevert(messageID: json['messageID'] as String);

Map<String, dynamic> _$SessionRevertToJson(_SessionRevert instance) =>
    <String, dynamic>{'messageID': instance.messageID};

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
  cost: (json['cost'] as num?)?.toDouble(),
  tokens: json['tokens'] == null
      ? null
      : TokenUsage.fromJson(json['tokens'] as Map<String, dynamic>),
  revert: json['revert'] == null
      ? null
      : SessionRevert.fromJson(json['revert'] as Map<String, dynamic>),
  outcome: json['outcome'] as String?,
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
  'cost': instance.cost,
  'tokens': instance.tokens,
  'revert': instance.revert,
  'outcome': instance.outcome,
};
