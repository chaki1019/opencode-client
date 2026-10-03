/// A dotted version such as `1.2.3`. A build suffix (`+4`) or pre-release
/// tag (`-beta`) is ignored, and missing parts count as zero, so `1.2`
/// equals `1.2.0`.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  final List<int> parts;

  /// Null when [text] does not start with a number.
  static AppVersion? tryParse(String? text) {
    final core = text?.trim().split(RegExp(r'[+\-]')).first ?? '';
    if (core.isEmpty) return null;
    final parts = <int>[];
    for (final part in core.split('.')) {
      final value = int.tryParse(part);
      if (value == null || value < 0) return null;
      parts.add(value);
    }
    return AppVersion(parts);
  }

  @override
  int compareTo(AppVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  String toString() => parts.join('.');
}

/// What the update server says about one platform.
class UpdatePolicy {
  const UpdatePolicy({this.minimum, this.storeUrl});

  /// Reads the platform's entry (`ios` or `android`) from the
  /// `/v1/app-version` response. Anything malformed means no minimum.
  factory UpdatePolicy.fromJson(Object? json, String platform) {
    final entry = json is Map ? json[platform] : null;
    if (entry is! Map) return const UpdatePolicy();
    final minimum = entry['minimum'];
    final storeUrl = entry['storeUrl'];
    return UpdatePolicy(
      minimum: minimum is String ? AppVersion.tryParse(minimum) : null,
      storeUrl: storeUrl is String && storeUrl.isNotEmpty ? storeUrl : null,
    );
  }

  final AppVersion? minimum;
  final String? storeUrl;

  bool requiresUpdate(AppVersion installed) {
    final minimum = this.minimum;
    return minimum != null && installed < minimum;
  }
}
