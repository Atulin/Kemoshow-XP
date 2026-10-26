import '../models/media_item.dart';

/// Progress of a media download, in bytes.
class MediaSaveProgress {
  const MediaSaveProgress({required this.receivedBytes, this.totalBytes});

  final int receivedBytes;

  /// Total size reported by the server, or null when it was not sent.
  final int? totalBytes;

  /// Completed fraction of the download, or null when the size is unknown.
  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}

/// Where a media file should be stored.
enum MediaSaveTarget {
  /// The system photo gallery. Only available where [MediaSaver.supportsGallery]
  /// is true.
  gallery,

  /// A folder picked by the user, either in an app folder picker (desktop) or
  /// in the system save dialog (mobile).
  folder,
}

/// Result of a successful save.
class MediaSaveResult {
  const MediaSaveResult({required this.destination});

  /// User-facing destination, e.g. `your gallery` or a folder path.
  final String destination;
}

/// Thrown when saving a media file fails for a reason worth showing the user.
class MediaSaveException implements Exception {
  const MediaSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Stores a slideshow item in the system gallery or a user-chosen folder.
abstract interface class MediaSaver {
  /// Whether media can be added to the system gallery on this platform.
  ///
  /// When false, only [MediaSaveTarget.folder] is supported.
  bool get supportsGallery;

  /// Downloads [item] and saves it to [target].
  ///
  /// [onProgress] is called with byte counts while the file downloads.
  /// Returns null when the user cancels the destination picker or dialog.
  Future<MediaSaveResult?> save(
    MediaItem item, {
    required MediaSaveTarget target,
    required void Function(MediaSaveProgress progress) onProgress,
  });
}
