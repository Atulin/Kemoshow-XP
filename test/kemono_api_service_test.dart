import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/services/kemono_api_service.dart';

Map<String, Object?> _postJson({
  String id = '1836570',
  String? title = 'A post',
}) {
  return {
    'id': id,
    'user': '6570768',
    'service': 'fanbox',
    'title': title,
    'content': '<p>Hello</p>',
    'embed': {},
    'shared_file': false,
    'added': '2021-03-30T18:00:05.973913',
    'published': '2021-01-24T17:54:38',
    'edited': '2021-01-24T18:46:15',
    'file': {'name': 'cover.jpg', 'path': '/5c/98/cover.jpg'},
    'attachments': [
      {'name': 'extra.png', 'path': '/d7/4d/extra.png'},
    ],
  };
}

void main() {
  test(
    'fetchPosts builds an offset search request and parses the response',
    () async {
      late http.Request captured;
      final service = KemonoApiService(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'count': 1,
              'true_count': 1,
              'posts': [_postJson()],
            }),
            200,
          );
        }),
      );

      final posts = await service.fetchPosts(
        server: KemonoServer.pawchive,
        query: 'cat',
        offset: 50,
      );

      expect(captured.url.scheme, 'https');
      expect(captured.url.host, 'pawchive.pw');
      expect(captured.url.path, '/api/v1/posts');
      expect(captured.url.queryParameters, {'q': 'cat', 'o': '50'});
      expect(captured.headers['Accept'], 'application/json');

      expect(posts, hasLength(1));
      expect(posts.single.id, '1836570');
      expect(posts.single.file?.path, '/5c/98/cover.jpg');
      expect(posts.single.allFiles, hasLength(2));
      expect(posts.single.publishedDate, DateTime(2021, 1, 24, 17, 54, 38));
    },
  );

  test('fetchPosts tolerates a bare list response', () async {
    final service = KemonoApiService(
      client: MockClient(
        (_) async => http.Response(jsonEncode([_postJson()]), 200),
      ),
    );

    final posts = await service.fetchPosts(
      server: KemonoServer.kemono,
      query: 'cat',
      offset: 0,
    );

    expect(posts, hasLength(1));
  });

  test('fetchCreatorPosts uses the creator service in the path', () async {
    late http.Request captured;
    final service = KemonoApiService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'props': {'count': 1234},
            'results': [_postJson(id: '9')],
          }),
          200,
        );
      }),
    );

    final posts = await service.fetchCreatorPosts(
      server: KemonoServer.coomer,
      service: 'fanbox',
      creatorId: '123',
      offset: 100,
    );

    expect(captured.url.host, 'coomer.su');
    expect(captured.url.path, '/api/v1/fanbox/user/123/posts');
    expect(captured.url.queryParameters, {'o': '100'});
    expect(posts.single.id, '9');
  });

  test('fetchCreators requests text/css and parses the directory', () async {
    late http.Request captured;
    final service = KemonoApiService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([
            {
              'favorited': 7,
              'id': '21101760',
              'indexed': 1672534800,
              'name': 'RAIGYO',
              'service': 'fanbox',
              'updated': 1672534800,
              // Fields the live API returns but the app does not model.
              'public_id': 'RAIGYO',
              'ever_imported': true,
            },
          ]),
          200,
        );
      }),
      parseCreatorsInIsolate: false,
    );

    final creators = await service.fetchCreators(server: KemonoServer.kemono);

    expect(captured.url.host, 'kemono.cr');
    expect(captured.url.path, '/api/v1/creators');
    expect(captured.headers['Accept'], 'text/css');
    expect(creators.single.id, '21101760');
    expect(creators.single.displayName, 'RAIGYO');
    expect(creators.single.favorited, 7);
  });

  test('parses the trimmed post shape returned by the live API', () async {
    final service = KemonoApiService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'id': '173400032',
              'user': '87165490',
              'service': 'patreon',
              'title': '[TBBT] Ch: 30',
              'substring': '<p>[AN: Slightly unedited.',
              'published': '2026-10-25T23:08:06',
              'file': <String, Object?>{},
              'attachments': <Object?>[],
              'preview_state': 'pending',
              'has_full': true,
              'origin': 'import',
            },
          ]),
          200,
        ),
      ),
    );

    final posts = await service.fetchPosts(
      server: KemonoServer.pawchive,
      query: 'test',
      offset: 0,
    );

    expect(posts.single.id, '173400032');
    expect(posts.single.title, '[TBBT] Ch: 30');
    expect(posts.single.sharedFile, isFalse);
    expect(posts.single.allFiles, isEmpty);
    expect(posts.single.file?.path, isNull);
  });

  test('throws a typed exception for a non-200 response', () async {
    final service = KemonoApiService(
      client: MockClient((_) async => http.Response('nope', 503)),
    );

    expect(
      () => service.fetchPosts(
        server: KemonoServer.pawchive,
        query: 'cat',
        offset: 0,
      ),
      throwsA(
        isA<KemonoApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
  });

  test('throws a typed exception for invalid JSON', () async {
    final service = KemonoApiService(
      client: MockClient((_) async => http.Response('<html>', 200)),
    );

    expect(
      () => service.fetchPosts(
        server: KemonoServer.pawchive,
        query: 'cat',
        offset: 0,
      ),
      throwsA(isA<KemonoApiException>()),
    );
  });
}
