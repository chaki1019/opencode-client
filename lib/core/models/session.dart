import 'package:freezed_annotation/freezed_annotation.dart';

part 'session.freezed.dart';
part 'session.g.dart';

@freezed
abstract class SessionLocation with _$SessionLocation {
  const factory SessionLocation({
    required String directory,
    String? workspaceID,
  }) = _SessionLocation;

  factory SessionLocation.fromJson(Map<String, dynamic> json) =>
      _$SessionLocationFromJson(json);
}

@freezed
abstract class SessionTime with _$SessionTime {
  const factory SessionTime({
    required double created,
    required double updated,
    double? archived,
  }) = _SessionTime;

  factory SessionTime.fromJson(Map<String, dynamic> json) =>
      _$SessionTimeFromJson(json);
}

@freezed
abstract class ModelRef with _$ModelRef {
  const ModelRef._();

  const factory ModelRef({
    required String providerID,
    required String id,
    String? variant,
  }) = _ModelRef;

  factory ModelRef.fromJson(Map<String, dynamic> json) =>
      _$ModelRefFromJson(json);

  String get label => variant == null ? id : '$id ($variant)';
}

/// A v2 session (`/api/session`). Times are epoch milliseconds.
@freezed
abstract class Session with _$Session {
  const Session._();

  const factory Session({
    required String id,
    required String projectID,
    String? parentID,
    String? title,
    required SessionLocation location,
    required SessionTime time,
    String? agent,
    ModelRef? model,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);

  /// The trimmed title, or null when the session has none yet.
  String? get displayTitle =>
      (title?.trim().isNotEmpty ?? false) ? title!.trim() : null;

  bool get isArchived => time.archived != null;

  DateTime get updatedAt =>
      DateTime.fromMillisecondsSinceEpoch(time.updated.round());
}
