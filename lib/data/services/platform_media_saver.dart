import 'dart:async';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/media_item.dart';
import '../../domain/services/media_saver.dart';
import '../../ui/core/platform_support.dart';
import 'media_file_names.dart';

/// Lets the user choose the folder media is saved to on desktop.
typedef DirectoryPicker = Future<String?> Function();

/// Opens the system save dialog for a downloaded file. Returns false when the
/// user cancels.
typedef MobileFileExporter = Future<bool> Function(String path);

/// Writes a downloaded file to the system gallery.
typedef GalleryWriter = Future<void> Function(String path, bool isVideo);

/// Asks for (and returns) permission to add media to the gallery.
typedef GalleryAccess = Future<bool> Function();

/// Provides the directory temporary downloads are written to.
typedef TemporaryDirectoryProvider = Future<Directory> Function();

/// Creates the HTTP client used for one download.
typedef ClientFactory = http.Client Function();

/// Saves media to the system gallery or a folder chosen by the user.
///
/// On mobile, gallery saves go through `gal` and folder saves through the
/// system save dialog (which writes through the Storage Access Framework on
/// Android). On desktop, the folder is chosen with a native directory picker.
class PlatformMediaSaver implements MediaSaver {
  PlatformMediaSaver({
    bool? mobile,
    this.directoryPicker,
    MobileFileExporter? fileExporter,
    GalleryWriter? galleryWriter,
    GalleryAccess? requestGalleryAccess,
    TemporaryDirectoryProvider? temporaryDirectory,
    ClientFactory? clientFactory,
    this.responseTimeout = const Duration(seconds: 30),
  }) : _mobile = mobile ?? !isDesktopPlatform,
       _fileExporter = fileExporter ?? _exportWithSaveDialog,
       _galleryWriter = galleryWriter ?? _writeToGallery,
       _galleryAccess = requestGalleryAccess ?? _ensureGalleryAccess,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _clientFactory = clientFactory ?? http.Client.new;

  /// Whether this is a mobile platform, where the gallery is available and
  /// folders are picked with the system save dialog. Overridable for tests.
  final bool _mobile;

  /// Overrides the desktop folder picker; used by tests.
  final DirectoryPicker? directoryPicker;

  /// Overrides the mobile save dialog; used by tests.
  final MobileFileExporter _fileExporter;

  final GalleryWriter _galleryWriter;
  final GalleryAccess _galleryAccess;
  final TemporaryDirectoryProvider _temporaryDirectory;
  final ClientFactory _clientFactory;

  /// How long to wait for the server to start sending a file. The download
  /// itself is not limited, since videos can be large.
  final Duration responseTimeout;

  /// Last folder chosen in this run, used to reopen the picker there.
  String? _lastDirectory;

  @override
  bool get supportsGallery => _mobile;

  @override
  Future<MediaSaveResult?> save(
    MediaItem item, {
    required MediaSaveTarget target,
    required void Function(MediaSaveProgress progress) onProgress,
  }) async {
    try {
      return switch (target) {
        MediaSaveTarget.gallery => await _saveToSystemGallery(item, onProgress),
        MediaSaveTarget.folder => await _saveToFolder(item, onProgress),
      };
    } on MediaSaveException {
      rethrow;
    } on GalException catch (error) {
      throw MediaSaveException(error.type.message);
    } on TimeoutException {
      throw const MediaSaveException('The download timed out.');
    } on http.ClientException catch (error) {
      throw MediaSaveException('Download failed: ${error.message}');
    } on FileSystemException catch (error) {
      throw MediaSaveException(
        'Could not write the file: ${error.osError?.message ?? error.message}',
      );
    } on PlatformException catch (error) {
      throw MediaSaveException(
        'The system save dialog failed: ${error.message ?? error.code}',
      );
    }
  }

  Future<MediaSaveResult?> _saveToSystemGallery(
    MediaItem item,
    void Function(MediaSaveProgress progress) onProgress,
  ) async {
    if (!_mobile) {
      throw const MediaSaveException(
        'Saving to the gallery is not available on this platform.',
      );
    }
    if (!await _galleryAccess()) {
      throw const MediaSaveException(
        'Permission to save to the gallery was denied.',
      );
    }

    final target = await _createTemporaryTarget(item);
    try {
      await _download(item, target, onProgress);
      await _galleryWriter(target.path, item.isVideo);
    } finally {
      await _deleteQuietly(target);
    }

    return const MediaSaveResult(destination: 'your gallery');
  }

  Future<MediaSaveResult?> _saveToFolder(
    MediaItem item,
    void Function(MediaSaveProgress progress) onProgress,
  ) => _mobile
      ? _saveWithDialog(item, onProgress)
      : _saveToChosenDirectory(item, onProgress);

  /// Downloads into the temporary directory, then lets the system save dialog
  /// copy the file to the folder the user picks.
  Future<MediaSaveResult?> _saveWithDialog(
    MediaItem item,
    void Function(MediaSaveProgress progress) onProgress,
  ) async {
    final target = await _createTemporaryTarget(item);
    try {
      await _download(item, target, onProgress);
      if (!await _fileExporter(target.path)) return null;
      return const MediaSaveResult(destination: 'the folder you chose');
    } finally {
      await _deleteQuietly(target);
    }
  }

  Future<MediaSaveResult?> _saveToChosenDirectory(
    MediaItem item,
    void Function(MediaSaveProgress progress) onProgress,
  ) async {
    final directory = await _chooseDirectory();
    if (directory == null) return null;

    final name = uniqueMediaFileName(
      mediaFileName(item),
      (candidate) => File(p.join(directory, candidate)).existsSync(),
    );
    final target = File(p.join(directory, name));

    var written = false;
    try {
      await _download(item, target, onProgress);
      written = true;
    } finally {
      if (!written) await _deleteQuietly(target);
    }

    return MediaSaveResult(destination: directory);
  }

  Future<File> _createTemporaryTarget(MediaItem item) async {
    final temporary = await _temporaryDirectory();
    final directory = Directory(p.join(temporary.path, 'kemoshow_downloads'));
    await directory.create(recursive: true);
    return File(p.join(directory.path, mediaFileName(item)));
  }

  Future<String?> _chooseDirectory() async {
    final picker = directoryPicker;
    if (picker != null) return picker();

    final directory = await getDirectoryPath(
      initialDirectory: _lastDirectory,
      confirmButtonText: 'Save here',
    );
    if (directory != null) _lastDirectory = directory;
    return directory;
  }

  Future<void> _download(
    MediaItem item,
    File target,
    void Function(MediaSaveProgress progress) onProgress,
  ) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null || uri.host.isEmpty) {
      throw const MediaSaveException('This media has an unsupported address.');
    }
    if (!uri.isScheme('http') && !uri.isScheme('https')) {
      throw const MediaSaveException('This media has an unsupported address.');
    }

    final client = _clientFactory();
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(responseTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MediaSaveException(
          'The media server returned HTTP ${response.statusCode}.',
        );
      }

      final total = response.contentLength;
      var received = 0;
      onProgress(MediaSaveProgress(receivedBytes: 0, totalBytes: total));

      final sink = target.openWrite();
      try {
        // addStream applies backpressure, so large videos are not buffered in
        // memory while the file is written.
        await sink.addStream(
          response.stream.map((chunk) {
            received += chunk.length;
            onProgress(
              MediaSaveProgress(receivedBytes: received, totalBytes: total),
            );
            return chunk;
          }),
        );
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (received == 0) {
        throw const MediaSaveException('The media server returned no data.');
      }
    } finally {
      client.close();
    }
  }

  static Future<bool> _exportWithSaveDialog(String path) async {
    final name = p.basename(path);
    final extension = p.extension(name);
    final saved = await FileSaver.instance.saveAs(
      name: extension.isEmpty
          ? name
          : name.substring(0, name.length - extension.length),
      filePath: path,
      fileExtension: extension,
      mimeType: MimeType.custom,
      customMimeType: mediaMimeType(name) ?? 'application/octet-stream',
    );
    return saved != null;
  }

  static Future<void> _writeToGallery(String path, bool isVideo) =>
      isVideo ? Gal.putVideo(path) : Gal.putImage(path);

  static Future<bool> _ensureGalleryAccess() async {
    if (await Gal.hasAccess()) return true;
    return Gal.requestAccess();
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best effort; the platform cleans its cache directory eventually.
    }
  }
}
