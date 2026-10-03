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

/// Token counts the server reports for a step or a whole session.
@freezed
abstract class TokenUsage with _$TokenUsage {
  const TokenUsage._();

  const factory TokenUsage({
    @Default(0) int input,
    @Default(0) int output,
    @Default(0) int reasoning,
    @Default(TokenCache()) TokenCache cache,
  }) = _TokenUsage;

  factory TokenUsage.fromJson(Map<String, dynamic> json) =>
      _$TokenUsageFromJson(json);

  /// Everything the step sent and received, which is what fills the
  /// model's context window.
  int get total => input + output + reasoning + cache.read + cache.write;
}

@freezed
abstract class TokenCache with _$TokenCache {
  const factory TokenCache({@Default(0) int read, @Default(0) int write}) =
      _TokenCache;

  factory TokenCache.fromJson(Map<String, dynamic> json) =>
      _$TokenCacheFromJson(json);
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

    /// Total spend in USD across the session.
    double? cost,

    /// Tokens used across the session.
    TokenUsage? tokens,
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
