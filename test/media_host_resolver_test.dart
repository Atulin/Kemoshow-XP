import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/services/media_host_resolver.dart';

void main() {
  const server = KemonoServer(
    host: 'coomer.st',
    dataHost: 'n3.coomer.st',
    previewHost: 'img.coomer.st',
  );

  test('uses the host the site redirects /data requests to', () async {
    final requests = <http.Request>[];
    final resolver = MediaHostResolver(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '',
          302,
          headers: {'location': 'https://n4.coomer.st/data/0c/f3/x.jpg'},
        );
      }),
    );
    addTearDown(resolver.dispose);

    final dataHost = await resolver.resolveDataHost(server, '0c/f3/x.jpg');

    expect(dataHost, 'n4.coomer.st');
    expect(requests.single.method, 'HEAD');
    expect(requests.single.url, Uri.https('coomer.st', '/data/0c/f3/x.jpg'));
    expect(requests.single.followRedirects, isFalse);
  });

  test('keeps the configured host when there is no redirect', () async {
    final resolver = MediaHostResolver(
      client: MockClient((_) async => http.Response('', 200)),
    );
    addTearDown(resolver.dispose);

    expect(
      await resolver.resolveDataHost(server, '0c/f3/x.jpg'),
      'n3.coomer.st',
    );
  });

  test(
    'falls back to the configured host when the site is unreachable',
    () async {
      final resolver = MediaHostResolver(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(resolver.dispose);

      expect(
        await resolver.resolveDataHost(server, '0c/f3/x.jpg'),
        'n3.coomer.st',
      );
    },
  );

  test('ignores unusable redirect targets', () async {
    final resolver = MediaHostResolver(
      client: MockClient(
        (_) async => http.Response('', 302, headers: {'location': 'garbage'}),
      ),
    );
    addTearDown(resolver.dispose);

    expect(
      await resolver.resolveDataHost(server, '0c/f3/x.jpg'),
      'n3.coomer.st',
    );
  });

  test('caches the resolution per site host', () async {
    var headRequests = 0;
    final resolver = MediaHostResolver(
      client: MockClient((_) async {
        headRequests++;
        return http.Response(
          '',
          302,
          headers: {'location': 'https://n4.coomer.st/data/x.jpg'},
        );
      }),
    );
    addTearDown(resolver.dispose);

    expect(await resolver.resolveDataHost(server, 'a.jpg'), 'n4.coomer.st');
    expect(await resolver.resolveDataHost(server, 'b.jpg'), 'n4.coomer.st');
    expect(resolver.cachedDataHost(server), 'n4.coomer.st');
    expect(headRequests, 1);
  });

  test('without a sample path the configured host is used', () async {
    var requests = 0;
    final resolver = MediaHostResolver(
      client: MockClient((_) async {
        requests++;
        return http.Response('', 302);
      }),
    );
    addTearDown(resolver.dispose);

    expect(await resolver.resolveDataHost(server, ''), 'n3.coomer.st');
    expect(requests, 0);
  });
}
