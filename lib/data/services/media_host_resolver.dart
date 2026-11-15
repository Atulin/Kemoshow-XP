import 'dart:async';

import 'package:http/http.dart' as http;

import '../../core/kemono_server.dart';

/// Discovers the media host a server currently redirects `/data/` requests to.
///
/// The `nX` media subdomains are shuffled whenever these sites move between
/// domains, so the configured [KemonoServer.dataHost] can go stale and media
/// requests start failing with HTTP 403. The site host itself still answers
/// `/data/<file>` with a redirect to the current media host; that redirect is
/// used to correct media URLs at runtime.
///
/// Resolutions are cached per site host for the lifetime of the app, so each
/// server costs at most one request per session.
class MediaHostResolver {
  MediaHostResolver({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Site host -> resolved media host.
  final Map<String, String> _cache = {};

  /// The media host resolved for [server], if one was discovered already.
  String? cachedDataHost(KemonoServer server) => _cache[server.host];

  /// Resolves the media host for [server] using [samplePath], a file path as
  /// returned by the API (e.g. `0c/f3/<hash>.jpg`, without a `/data/` prefix).
  ///
  /// Falls back to the configured [KemonoServer.dataHost] when the site does
  /// not redirect, cannot be reached or the redirect target is unusable.
  Future<String> resolveDataHost(KemonoServer server, String samplePath) async {
    final cached = _cache[server.host];
    if (cached != null) return cached;

    final path = samplePath.startsWith('/')
        ? samplePath.substring(1)
        : samplePath;
    if (path.isEmpty) return server.dataHost;

    try {
      final request = http.Request(
        'HEAD',
        Uri.https(server.host, '/data/$path'),
      )..followRedirects = false;
      final response = await _client.send(request).timeout(timeout);
      final location = response.headers['location'];
      if (location != null) {
        final host = Uri.tryParse(location)?.host ?? '';
        if (host.isNotEmpty && KemonoServer.isValidHost(host)) {
          _cache[server.host] = host;
          return host;
        }
      }
    } catch (_) {
      // Resolution is best-effort; the configured host is the next guess.
    }
    return server.dataHost;
  }

  /// Releases the underlying HTTP connections.
  void dispose() => _client.close();
}
