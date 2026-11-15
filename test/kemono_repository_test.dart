import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/models/post.dart';
import 'package:kemoshow/data/repositories/kemono_repository.dart';
import 'package:kemoshow/data/services/kemono_api_service.dart';
import 'package:kemoshow/data/services/media_host_resolver.dart';
import 'package:kemoshow/domain/models/slideshow_source.dart';

/// The API lists file paths without a `/data/` prefix; the site host answers
/// `/data/<file>` with a redirect to the media host that currently serves
/// files. The repository is expected to follow that redirect so a stale
/// configured media host heals itself instead of failing with HTTP 403.
void main() {
  const server = KemonoServer(
    host: 'coomer.st',
    dataHost: 'n3.coomer.st',
    previewHost: 'img.coomer.st',
  );
  const redirectedHost = 'n4.coomer.st';

  http.Client mockClient({
    String redirectHost = redirectedHost,
    bool redirect = true,
  }) {
    return MockClient((request) async {
      if (request.method == 'HEAD') {
        if (!redirect) return http.Response('', 200);
        return http.Response(
          '',
          302,
          headers: {'location': 'https://$redirectHost/data/0c/f3/x.jpg'},
        );
      }
      final path = request.url.path;
      if (path.endsWith('/posts')) {
        return http.Response(
          jsonEncode([
            {
              'id': '1',
              'user': 'u',
              'service': 'onlyfans',
              'file': {
                'name': 'a.jpg',
                'path':
                    '/0c/f3/0cf34a209c63785a8c12fc2ac6411e667e0461710603146dabd98448375b7569.jpg',
              },
              'attachments': [],
            },
          ]),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'id': '1',
          'user': 'u',
          'service': 'onlyfans',
          'file': {'name': 'a.jpg', 'path': '/0c/f3/ab.jpg'},
          'attachments': [],
          'content': '<a href="/data/ab/linked.jpg">file</a>',
        }),
        200,
      );
    });
  }

  test('builds media URLs with the redirected media host', () async {
    final client = mockClient();
    final repository = KemonoRepository(
      KemonoApiService(client: client),
      mediaHostResolver: MediaHostResolver(client: client),
    );
    addTearDown(repository.dispose);

    final page = await repository.fetchMediaPage(
      server: server,
      source: const PostSearchSource('cats'),
      offset: 0,
      includeLinkedMedia: false,
    );

    expect(
      page.items.single.url,
      'https://$redirectedHost/data/0c/f3/0cf34a209c63785a8c12fc2ac6411e667e0461710603146dabd98448375b7569.jpg',
    );
  });

  test(
    'keeps the configured media host when the site does not redirect',
    () async {
      final client = mockClient(redirect: false);
      final repository = KemonoRepository(
        KemonoApiService(client: client),
        mediaHostResolver: MediaHostResolver(client: client),
      );
      addTearDown(repository.dispose);

      final page = await repository.fetchMediaPage(
        server: server,
        source: const PostSearchSource('cats'),
        offset: 0,
        includeLinkedMedia: false,
      );

      expect(
        page.items.single.url,
        'https://n3.coomer.st/data/0c/f3/0cf34a209c63785a8c12fc2ac6411e667e0461710603146dabd98448375b7569.jpg',
      );
    },
  );

  test('resolves the media host only once per server', () async {
    var headRequests = 0;
    final client = MockClient((request) async {
      if (request.method == 'HEAD') {
        headRequests++;
        return http.Response(
          '',
          302,
          headers: {'location': 'https://$redirectedHost/data/x.jpg'},
        );
      }
      final offset = request.url.queryParameters['o'] ?? '0';
      if (offset == '0') {
        return http.Response(
          jsonEncode([
            {
              'id': '1',
              'user': 'u',
              'service': 'onlyfans',
              'file': {'name': 'a.jpg', 'path': '/0c/f3/ab.jpg'},
            },
          ]),
          200,
        );
      }
      return http.Response(jsonEncode(const []), 200);
    });
    final repository = KemonoRepository(
      KemonoApiService(client: client),
      mediaHostResolver: MediaHostResolver(client: client),
    );
    addTearDown(repository.dispose);

    await repository.fetchMediaPage(
      server: server,
      source: const PostSearchSource('cats'),
      offset: 0,
      includeLinkedMedia: false,
    );
    await repository.fetchMediaPage(
      server: server,
      source: const PostSearchSource('cats'),
      offset: 50,
      includeLinkedMedia: false,
    );

    expect(headRequests, 1);
  });

  test('rewrites body file links to the redirected media host', () async {
    final client = mockClient();
    final repository = KemonoRepository(
      KemonoApiService(client: client),
      mediaHostResolver: MediaHostResolver(client: client),
    );
    addTearDown(repository.dispose);

    final post = await repository.fetchPost(
      server: server,
      post: const Post(id: '1', user: 'u', service: 'onlyfans'),
    );

    expect(
      post?.content,
      '<a href="https://$redirectedHost/data/ab/linked.jpg">file</a>',
    );
  });
}
