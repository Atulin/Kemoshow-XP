import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kemoshow/data/models/post.dart';
import 'package:kemoshow/data/services/media_file_names.dart';
import 'package:kemoshow/data/services/platform_media_saver.dart';
import 'package:kemoshow/domain/models/media_item.dart';
import 'package:kemoshow/domain/services/media_saver.dart';
import 'package:path/path.dart' as p;

MediaItem _item({
  String name = 'clip.mp4',
  MediaKind kind = MediaKind.video,
  String url = 'https://n2.pawchive.pw/data/ab/clip.mp4',
}) => MediaItem(
  url: url,
  name: name,
  kind: kind,
  post: const Post(id: '1'),
  isAttachment: false,
);

http.Client _streamingClient(
  List<int> bytes, {
  int statusCode = 200,
  int? contentLength,
}) {
  return MockClient.streaming((request, bodyStream) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      statusCode,
      contentLength: contentLength ?? bytes.length,
    );
  });
}

void main() {
  group('sanitizeMediaFileName', () {
    test('keeps ordinary names and extensions', () {
      expect(
        sanitizeMediaFileName('cover.PNG', kind: MediaKind.image),
        'cover.PNG',
      );
      expect(
        sanitizeMediaFileName('clip.mp4', kind: MediaKind.video),
        'clip.mp4',
      );
    });

    test('replaces characters that are invalid on common filesystems', () {
      expect(
        sanitizeMediaFileName(r'a:b*c?d"e<f>g|h.mp4', kind: MediaKind.video),
        'a_b_c_d_e_f_g_h.mp4',
      );
    });

    test('strips path separators and leading dots', () {
      expect(
        sanitizeMediaFileName('../evil/name.png', kind: MediaKind.image),
        '_evil_name.png',
      );
    });

    test('collapses whitespace and trims the stem', () {
      expect(
        sanitizeMediaFileName('  spaced   name .jpg  ', kind: MediaKind.image),
        'spaced name.jpg',
      );
    });

    test('adds an extension when the name has none', () {
      expect(sanitizeMediaFileName('clip', kind: MediaKind.video), 'clip.mp4');
      expect(
        sanitizeMediaFileName('cover', kind: MediaKind.image),
        'cover.jpg',
      );
    });

    test('avoids Windows device names and caps long stems', () {
      expect(
        sanitizeMediaFileName('CON.png', kind: MediaKind.image),
        '_CON.png',
      );

      final result = sanitizeMediaFileName(
        '${'x' * 300}.webm',
        kind: MediaKind.video,
      );
      expect(result, endsWith('.webm'));
      expect(result.length, lessThanOrEqualTo(96 + '.webm'.length));
    });

    test('falls back to a generated name for empty input', () {
      final result = sanitizeMediaFileName('   ', kind: MediaKind.image);
      expect(result, startsWith('kemoshow-'));
      expect(result, endsWith('.jpg'));
    });
  });

  group('uniqueMediaFileName', () {
    test('adds a counter when the name is taken', () {
      final existing = {'clip.mp4', 'clip (1).mp4'};

      expect(
        uniqueMediaFileName('clip.mp4', existing.contains),
        'clip (2).mp4',
      );
      expect(uniqueMediaFileName('other.mp4', existing.contains), 'other.mp4');
    });
  });

  group('mediaMimeType', () {
    test('maps common image and video extensions', () {
      expect(mediaMimeType('cover.png'), 'image/png');
      expect(mediaMimeType('cover.JPG'), 'image/jpeg');
      expect(mediaMimeType('anim.gif'), 'image/gif');
      expect(mediaMimeType('clip.mp4'), 'video/mp4');
      expect(mediaMimeType('clip.webm'), 'video/webm');
    });

    test('returns null for unknown extensions', () {
      expect(mediaMimeType('notes.txt'), isNull);
      expect(mediaMimeType('no-extension'), isNull);
    });
  });

  group('PlatformMediaSaver desktop', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('kemoshow_saver_');
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('downloads into the chosen folder and reports progress', () async {
      final bytes = utf8.encode('image-bytes');
      final progress = <MediaSaveProgress>[];
      final saver = PlatformMediaSaver(
        mobile: false,
        directoryPicker: () async => directory.path,
        clientFactory: () => _streamingClient(bytes),
      );

      final result = await saver.save(
        _item(
          name: 'cover.png',
          kind: MediaKind.image,
          url: 'https://n2.pawchive.pw/data/ab/cover.png',
        ),
        target: MediaSaveTarget.folder,
        onProgress: progress.add,
      );

      expect(result, isNotNull);
      expect(result!.destination, directory.path);
      expect(
        await File(p.join(directory.path, 'cover.png')).readAsBytes(),
        bytes,
      );

      expect(progress, isNotEmpty);
      expect(progress.first.receivedBytes, 0);
      expect(progress.last.receivedBytes, bytes.length);
      expect(progress.last.totalBytes, bytes.length);
    });

    test('does not overwrite existing files', () async {
      final existing = File(p.join(directory.path, 'cover.png'));
      await existing.writeAsBytes([1]);

      final saver = PlatformMediaSaver(
        mobile: false,
        directoryPicker: () async => directory.path,
        clientFactory: () => _streamingClient(utf8.encode('new')),
      );

      await saver.save(
        _item(name: 'cover.png', kind: MediaKind.image),
        target: MediaSaveTarget.folder,
        onProgress: (_) {},
      );

      expect(await existing.readAsBytes(), [1]);
      expect(
        await File(p.join(directory.path, 'cover (1).png')).readAsString(),
        'new',
      );
    });

    test(
      'returns null and downloads nothing when the picker is cancelled',
      () async {
        var clientCreated = false;
        final saver = PlatformMediaSaver(
          mobile: false,
          directoryPicker: () async => null,
          clientFactory: () {
            clientCreated = true;
            return _streamingClient(const []);
          },
        );

        final result = await saver.save(
          _item(),
          target: MediaSaveTarget.folder,
          onProgress: (_) {},
        );

        expect(result, isNull);
        expect(clientCreated, isFalse);
        expect(directory.listSync(), isEmpty);
      },
    );

    test('surfaces HTTP errors without leaving a partial file', () async {
      final saver = PlatformMediaSaver(
        mobile: false,
        directoryPicker: () async => directory.path,
        clientFactory: () => _streamingClient(const [], statusCode: 404),
      );

      await expectLater(
        saver.save(_item(), target: MediaSaveTarget.folder, onProgress: (_) {}),
        throwsA(isA<MediaSaveException>()),
      );
      expect(directory.listSync(), isEmpty);
    });

    test('has no gallery target', () async {
      var clientCreated = false;
      final saver = PlatformMediaSaver(
        mobile: false,
        clientFactory: () {
          clientCreated = true;
          return _streamingClient(const []);
        },
      );

      expect(saver.supportsGallery, isFalse);
      await expectLater(
        saver.save(
          _item(),
          target: MediaSaveTarget.gallery,
          onProgress: (_) {},
        ),
        throwsA(isA<MediaSaveException>()),
      );
      expect(clientCreated, isFalse);
    });
  });

  group('PlatformMediaSaver gallery', () {
    late Directory temporary;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('kemoshow_gallery_');
    });

    tearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });

    test('hands a temporary file to the gallery and cleans it up', () async {
      String? handedPath;
      bool? handedIsVideo;
      final saver = PlatformMediaSaver(
        mobile: true,
        requestGalleryAccess: () async => true,
        temporaryDirectory: () async => temporary,
        galleryWriter: (path, isVideo) async {
          handedPath = path;
          handedIsVideo = isVideo;
          expect(await File(path).readAsString(), 'video-bytes');
        },
        clientFactory: () => _streamingClient(utf8.encode('video-bytes')),
      );

      final result = await saver.save(
        _item(),
        target: MediaSaveTarget.gallery,
        onProgress: (_) {},
      );

      expect(saver.supportsGallery, isTrue);
      expect(result?.destination, 'your gallery');
      expect(handedIsVideo, isTrue);
      expect(p.basename(handedPath!), 'clip.mp4');
      expect(await File(handedPath!).exists(), isFalse);
    });

    test('does not download when gallery access is denied', () async {
      var clientCreated = false;
      final saver = PlatformMediaSaver(
        mobile: true,
        requestGalleryAccess: () async => false,
        temporaryDirectory: () async => temporary,
        clientFactory: () {
          clientCreated = true;
          return _streamingClient(const []);
        },
      );

      await expectLater(
        saver.save(
          _item(),
          target: MediaSaveTarget.gallery,
          onProgress: (_) {},
        ),
        throwsA(
          isA<MediaSaveException>().having(
            (error) => error.message,
            'message',
            contains('denied'),
          ),
        ),
      );
      expect(clientCreated, isFalse);
    });

    test('removes the temporary file when the gallery write fails', () async {
      final saver = PlatformMediaSaver(
        mobile: true,
        requestGalleryAccess: () async => true,
        temporaryDirectory: () async => temporary,
        galleryWriter: (path, isVideo) async {
          throw StateError('gallery failed');
        },
        clientFactory: () => _streamingClient(utf8.encode('bytes')),
      );

      await expectLater(
        saver.save(
          _item(),
          target: MediaSaveTarget.gallery,
          onProgress: (_) {},
        ),
        throwsA(isA<StateError>()),
      );

      final downloads = Directory(p.join(temporary.path, 'kemoshow_downloads'));
      expect(downloads.existsSync() ? downloads.listSync() : const [], isEmpty);
    });
  });

  group('PlatformMediaSaver mobile folder', () {
    late Directory temporary;

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('kemoshow_export_');
    });

    tearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });

    test(
      'downloads, exports the file, and cleans the temporary copy',
      () async {
        String? exportedPath;
        final saver = PlatformMediaSaver(
          mobile: true,
          temporaryDirectory: () async => temporary,
          fileExporter: (path) async {
            exportedPath = path;
            expect(await File(path).readAsString(), 'video-bytes');
            return true;
          },
          clientFactory: () => _streamingClient(utf8.encode('video-bytes')),
        );

        final result = await saver.save(
          _item(),
          target: MediaSaveTarget.folder,
          onProgress: (_) {},
        );

        expect(result?.destination, 'the folder you chose');
        expect(p.basename(exportedPath!), 'clip.mp4');
        expect(await File(exportedPath!).exists(), isFalse);
      },
    );

    test('returns null when the save dialog is cancelled', () async {
      final saver = PlatformMediaSaver(
        mobile: true,
        temporaryDirectory: () async => temporary,
        fileExporter: (path) async => false,
        clientFactory: () => _streamingClient(utf8.encode('bytes')),
      );

      final result = await saver.save(
        _item(),
        target: MediaSaveTarget.folder,
        onProgress: (_) {},
      );

      expect(result, isNull);
      final downloads = Directory(p.join(temporary.path, 'kemoshow_downloads'));
      expect(downloads.existsSync() ? downloads.listSync() : const [], isEmpty);
    });

    test('cleans up when the save dialog fails', () async {
      final saver = PlatformMediaSaver(
        mobile: true,
        temporaryDirectory: () async => temporary,
        fileExporter: (path) async => throw StateError('dialog failed'),
        clientFactory: () => _streamingClient(utf8.encode('bytes')),
      );

      await expectLater(
        saver.save(_item(), target: MediaSaveTarget.folder, onProgress: (_) {}),
        throwsA(isA<StateError>()),
      );

      final downloads = Directory(p.join(temporary.path, 'kemoshow_downloads'));
      expect(downloads.existsSync() ? downloads.listSync() : const [], isEmpty);
    });
  });
}
