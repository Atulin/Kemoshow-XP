import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/data/models/post.dart';
import 'package:kemoshow/domain/models/media_item.dart';

void main() {
  group('MediaItem.flattenPosts', () {
    test('flattens the primary file and attachments in order', () {
      const post = Post(
        id: '1',
        user: '42',
        service: 'fanbox',
        file: PostFile(name: 'cover.jpg', path: '/aa/cover.jpg'),
        attachments: [
          PostFile(name: 'clip.mp4', path: '/bb/clip.mp4'),
          PostFile(name: 'page.png', path: '/cc/page.png'),
        ],
      );

      final items = MediaItem.flattenPosts([
        post,
      ], mediaBase: 'https://n2.pawchive.pw/data');

      expect(items.map((item) => item.url), [
        'https://n2.pawchive.pw/data/aa/cover.jpg',
        'https://n2.pawchive.pw/data/bb/clip.mp4',
        'https://n2.pawchive.pw/data/cc/page.png',
      ]);
      expect(items.map((item) => item.kind), [
        MediaKind.image,
        MediaKind.video,
        MediaKind.image,
      ]);
      expect(items.map((item) => item.isAttachment), [false, true, true]);
      expect(items.every((item) => item.post.id == '1'), isTrue);
    });

    test('skips files without a path', () {
      const post = Post(
        id: '2',
        file: PostFile(name: 'nothing.jpg'),
        attachments: [PostFile(path: '')],
      );

      expect(
        MediaItem.flattenPosts([
          post,
        ], mediaBase: 'https://n2.pawchive.pw/data'),
        isEmpty,
      );
    });

    test('normalizes trailing slash in the media base and missing leading '
        'slash in the path', () {
      const post = Post(
        id: '3',
        file: PostFile(path: 'dd/image.gif'),
      );

      final items = MediaItem.flattenPosts([
        post,
      ], mediaBase: 'https://n3.coomer.st/data/');

      expect(items.single.url, 'https://n3.coomer.st/data/dd/image.gif');
      expect(items.single.name, 'image.gif');
    });

    test('derives the file name from the path when the API omits it', () {
      const post = Post(
        id: '4',
        file: PostFile(path: '/ee/ff/video.webm'),
      );

      final items = MediaItem.flattenPosts([
        post,
      ], mediaBase: 'https://n4.kemono.cr/data');

      expect(items.single.name, 'video.webm');
      expect(items.single.kind, MediaKind.video);
    });

    test('keeps posts without media out of the flattened list', () {
      final items = MediaItem.flattenPosts(const [
        Post(id: '5'),
        Post(id: '6'),
      ], mediaBase: 'https://n2.pawchive.pw/data');

      expect(items, isEmpty);
    });
  });

  group('MediaItem.kindFromName', () {
    test('detects video extensions case-insensitively', () {
      for (final name in ['a.MP4', 'b.webm', 'c.MOV', 'd.mkv', 'e.ts']) {
        expect(MediaItem.kindFromName(name), MediaKind.video, reason: name);
      }
    });

    test('treats images and unknown extensions as images', () {
      for (final name in ['a.jpg', 'b.PNG', 'c.gif', 'd.webp', 'noext']) {
        expect(MediaItem.kindFromName(name), MediaKind.image, reason: name);
      }
    });
  });
}
