import 'package:path/path.dart' as p;

import '../../domain/models/media_item.dart';

/// Characters that are invalid in file names on at least one supported
/// platform (Windows is the strictest).
final RegExp _invalidCharacters = RegExp(r'[\x00-\x1F\x7F<>:"/\\|?*]');
final RegExp _whitespace = RegExp(r'\s+');
final RegExp _leadingDots = RegExp(r'^\.+');
final RegExp _trailingDotsOrSpaces = RegExp(r'[. ]+$');

/// Longest stem (hand-written, before the extension) that is kept. Media host
/// names can be very long, which trips filesystem limits.
const int _maxStemLength = 96;

/// Device names Windows refuses to use as file names.
const Set<String> _reservedWindowsNames = {
  'CON',
  'PRN',
  'AUX',
  'NUL',
  'COM1',
  'COM2',
  'COM3',
  'COM4',
  'COM5',
  'COM6',
  'COM7',
  'COM8',
  'COM9',
  'LPT1',
  'LPT2',
  'LPT3',
  'LPT4',
  'LPT5',
  'LPT6',
  'LPT7',
  'LPT8',
  'LPT9',
};

/// The file name a [MediaItem] should be saved as.
String mediaFileName(MediaItem item) =>
    sanitizeMediaFileName(item.name, kind: item.kind);

/// Turns an arbitrary media name into a safe file name while keeping its
/// extension.
///
/// When the name has no extension, one matching [kind] is added, because photo
/// galleries need a recognizable extension to classify a file.
String sanitizeMediaFileName(String raw, {required MediaKind kind}) {
  var name = raw.replaceAll(_invalidCharacters, '_');
  name = name.replaceAll(_whitespace, ' ').trim();
  name = name.replaceAll(_leadingDots, '');
  name = name.replaceAll(_trailingDotsOrSpaces, '').trim();
  if (name.isEmpty) {
    name = 'kemoshow-${DateTime.now().millisecondsSinceEpoch}';
  }

  var extension = p.extension(name);
  var stem = extension.isEmpty
      ? name
      : name.substring(0, name.length - extension.length);
  stem = stem.trim();
  if (stem.isEmpty) stem = 'media';

  if (_reservedWindowsNames.contains(stem.toUpperCase())) {
    stem = '_$stem';
  }
  if (stem.length > _maxStemLength) {
    stem = stem.substring(0, _maxStemLength).trimRight();
  }
  if (extension.isEmpty) {
    extension = kind == MediaKind.video ? '.mp4' : '.jpg';
  }

  return '$stem$extension';
}

/// Returns [fileName], suffixed with ` (1)`, ` (2)`, … when needed so that
/// [exists] is false. Falls back to a timestamp after 999 collisions.
String uniqueMediaFileName(
  String fileName,
  bool Function(String candidate) exists,
) {
  if (!exists(fileName)) return fileName;

  final extension = p.extension(fileName);
  final stem = extension.isEmpty
      ? fileName
      : fileName.substring(0, fileName.length - extension.length);

  for (var index = 1; index <= 999; index++) {
    final candidate = '$stem ($index)$extension';
    if (!exists(candidate)) return candidate;
  }

  return '$stem-${DateTime.now().millisecondsSinceEpoch}$extension';
}

/// Best-effort MIME type for [fileName], used by the mobile save dialog so the
/// picked destination keeps the right file type and extension.
String? mediaMimeType(String fileName) {
  return switch (p.extension(fileName).toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.avif' => 'image/avif',
    '.mp4' => 'video/mp4',
    '.webm' => 'video/webm',
    '.mov' => 'video/quicktime',
    '.m4v' => 'video/x-m4v',
    _ => null,
  };
}
