// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ServerConfig _$ServerConfigFromJson(Map<String, dynamic> json) =>
    _ServerConfig(
      id: json['id'] as String,
      baseUrl: json['baseUrl'] as String,
      username: json['username'] as String? ?? 'opencode',
      label: json['label'] as String?,
    );

Map<String, dynamic> _$ServerConfigToJson(_ServerConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'baseUrl': instance.baseUrl,
      'username': instance.username,
      'label': instance.label,
    };
