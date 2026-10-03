/// Absolute folder paths on the server, which may be POSIX (`/home/me`)
/// or Windows (`C:\Users\me`).
abstract final class ServerPath {
  static final _drive = RegExp(r'^[A-Za-z]:[\\/]');

  static bool _isWindows(String path) => _drive.hasMatch(path);

  static String separatorOf(String path) => _isWindows(path) ? r'\' : '/';

  static bool isAbsolute(String path) =>
      path.startsWith('/') || _isWindows(path);

  /// Trims whitespace and a trailing separator (except on a root).
  static String normalize(String input) {
    var path = input.trim();
    while (path.length > 1 &&
        (path.endsWith('/') || path.endsWith(r'\')) &&
        !_isRoot(path)) {
      path = path.substring(0, path.length - 1);
    }
    return path;
  }

  static bool _isRoot(String path) =>
      path == '/' || (path.length == 3 && _isWindows(path));

  /// [relative] is a path the server returned relative to [directory],
  /// possibly with a trailing separator.
  static String join(String directory, String relative) {
    final sep = separatorOf(directory);
    final child = normalize(relative);
    return directory.endsWith(sep)
        ? '$directory$child'
        : '$directory$sep$child';
  }

  /// Null for a root.
  static String? parent(String path) {
    if (_isRoot(path)) return null;
    final sep = separatorOf(path);
    final i = path.lastIndexOf(sep);
    if (i < 0) return null;
    final root = _isWindows(path) ? path.substring(0, 3) : '/';
    return i < root.length ? root : path.substring(0, i);
  }

  /// The last path component; the root itself for a root.
  static String name(String path) {
    final trimmed = normalize(path);
    if (_isRoot(trimmed)) return trimmed;
    final i = trimmed.lastIndexOf(separatorOf(trimmed));
    return i < 0 ? trimmed : trimmed.substring(i + 1);
  }

  /// Each folder from the root down to [path], as (label, path).
  static List<(String, String)> crumbs(String path) {
    final crumbs = <(String, String)>[];
    for (String? p = path; p != null; p = parent(p)) {
      crumbs.add((name(p), p));
    }
    return crumbs.reversed.toList();
  }
}
