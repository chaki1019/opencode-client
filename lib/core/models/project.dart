import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

@freezed
abstract class ProjectIcon with _$ProjectIcon {
  const factory ProjectIcon({
    String? url,
    @JsonKey(name: 'override') String? overrideUrl,
    String? color,
  }) = _ProjectIcon;

  factory ProjectIcon.fromJson(Map<String, dynamic> json) =>
      _$ProjectIconFromJson(json);
}

@freezed
abstract class ProjectTime with _$ProjectTime {
  const factory ProjectTime({double? created, double? updated}) = _ProjectTime;

  factory ProjectTime.fromJson(Map<String, dynamic> json) =>
      _$ProjectTimeFromJson(json);
}

/// A project known to the server. [directory] is the primary (canonical)
/// directory that scopes sessions and events for the project.
@freezed
abstract class Project with _$Project {
  const Project._();

  const factory Project({
    required String id,
    @JsonKey(name: 'canonical') required String directory,
    String? vcs,
    String? name,
    @Default(<String>[]) List<String> sandboxes,
    ProjectIcon? icon,
    ProjectTime? time,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) =>
      _$ProjectFromJson(json);

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    final parts = directory.split('/').where((p) => p.isNotEmpty);
    return parts.isEmpty ? directory : parts.last;
  }
}
