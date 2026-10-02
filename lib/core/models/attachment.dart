import 'dart:convert';
import 'dart:typed_data';

/// A file the user attaches to a prompt. v2 takes attachments inline as
/// data URLs (`files: [{uri, name}]`); there is no upload endpoint.
class PromptFile {
  const PromptFile({
    required this.name,
    required this.mime,
    required this.bytes,
  });

  /// Per-file and per-message limits, matching what the server accepts
  /// comfortably over a JSON body.
  static const maxFiles = 10;
  static const maxFileBytes = 10 * 1024 * 1024;
  static const maxTotalBytes = 24 * 1024 * 1024;

  final String name;
  final String mime;
  final Uint8List bytes;

  bool get isImage => mime.startsWith('image/');

  Map<String, Object> toJson() => {
    'uri': 'data:$mime;base64,${base64Encode(bytes)}',
    'name': name,
  };

  /// Guesses an image MIME type from a file name.
  static String mimeForName(String name) {
    final dot = name.lastIndexOf('.');
    return switch (dot < 0 ? '' : name.substring(dot + 1).toLowerCase()) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
  }

  /// Returns the limit that adding [adding] to [current] would break, or
  /// null when it fits.
  static AttachmentLimit? checkLimits(
    List<PromptFile> current,
    List<PromptFile> adding,
  ) {
    if (current.length + adding.length > maxFiles) {
      return AttachmentLimit.fileCount;
    }
    if (adding.any((f) => f.bytes.length > maxFileBytes)) {
      return AttachmentLimit.fileSize;
    }
    final total = [
      ...current,
      ...adding,
    ].fold<int>(0, (sum, f) => sum + f.bytes.length);
    if (total > maxTotalBytes) return AttachmentLimit.totalSize;
    return null;
  }
}

enum AttachmentLimit { fileCount, fileSize, totalSize }
