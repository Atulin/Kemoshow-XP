import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/core/kemono_server.dart';

void main() {
  group('KemonoServer', () {
    test('builds the web URL of a post', () {
      final url = KemonoServer.pawchive.postUrl(
        postId: '77447876',
        service: 'patreon',
        creatorId: '2613194',
      );

      expect(
        url.toString(),
        'https://pawchive.pw/patreon/user/2613194/post/77447876',
      );
    });

    test('has no post URL without a service or creator', () {
      expect(
        KemonoServer.pawchive.postUrl(postId: '1', creatorId: '2'),
        isNull,
      );
      expect(
        KemonoServer.pawchive.postUrl(postId: '1', service: 'patreon'),
        isNull,
      );
      expect(KemonoServer.pawchive.postUrl(postId: ''), isNull);
    });

    test('resolves absolute and protocol-relative body URLs', () {
      const server = KemonoServer.pawchive;

      expect(
        server.resolveBodyUrl('https://example.com/a.jpg'),
        'https://example.com/a.jpg',
      );
      expect(
        server.resolveBodyUrl('  //n2.pawchive.pw/data/a.jpg  '),
        'https://n2.pawchive.pw/data/a.jpg',
      );
    });

    test('resolves body files against the media hosts', () {
      const server = KemonoServer.pawchive;

      expect(
        server.resolveBodyUrl('/data/aa/picture.jpg'),
        'https://n2.pawchive.pw/data/aa/picture.jpg',
      );
      expect(
        server.resolveBodyUrl('data/aa/picture.jpg'),
        'https://n2.pawchive.pw/data/aa/picture.jpg',
      );
      expect(
        server.resolveBodyUrl('/thumbnail/data/aa/picture.jpg'),
        'https://img.pawchive.pw/thumbnail/data/aa/picture.jpg',
      );
      expect(
        server.resolveBodyUrl('/patreon/user/1/post/2'),
        'https://pawchive.pw/patreon/user/1/post/2',
      );
    });
  });
}
