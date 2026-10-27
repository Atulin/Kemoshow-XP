/// The Kemono-type servers supported by the application.
///
/// Media is not necessarily served from the same host as the API, hence the
/// separate [dataHost]. Posts that have not been archived completely yet only
/// serve a downscaled preview, which lives on [previewHost].
enum KemonoServer {
  pawchive(
    host: 'pawchive.pw',
    dataHost: 'n2.pawchive.pw',
    previewHost: 'img.pawchive.pw',
  ),
  kemono(
    host: 'kemono.cr',
    dataHost: 'n4.kemono.cr',
    previewHost: 'img.kemono.cr',
  ),
  coomer(
    host: 'coomer.su',
    dataHost: 'n3.coomer.st',
    previewHost: 'img.coomer.st',
  );

  const KemonoServer({
    required this.host,
    required this.dataHost,
    required this.previewHost,
  });

  /// Host serving the web UI and API.
  final String host;

  /// Host serving media files under `/data/`.
  final String dataHost;

  /// Host serving preview images under `/thumbnail/data/`.
  final String previewHost;

  static const KemonoServer defaultServer = KemonoServer.pawchive;

  /// Base URL of the API, e.g. `https://pawchive.pw/api`.
  Uri get apiBase => Uri.https(host, '/api');

  /// Prefix that media paths from the API are appended to.
  String get mediaBase => 'https://$dataHost/data';

  /// Prefix that preview paths from the API are appended to.
  ///
  /// Used as a fallback for posts whose full files are not archived yet.
  String get previewBase => 'https://$previewHost/thumbnail/data';

  /// Human readable name, used in the server picker.
  String get label => host;

  /// Web URL of a post, e.g. `https://pawchive.pw/patreon/user/123/post/456`.
  ///
  /// Returns null when the API did not include the service or creator that the
  /// URL needs, e.g. for unlisted posts.
  Uri? postUrl({required String postId, String? service, String? creatorId}) {
    if (postId.isEmpty) return null;
    if (service == null || service.isEmpty) return null;
    if (creatorId == null || creatorId.isEmpty) return null;
    return Uri.https(host, '/$service/user/$creatorId/post/$postId');
  }

  /// Resolves a URL found in a post body to an absolute one.
  ///
  /// Bodies use relative paths such as `/data/...` or `/thumbnail/data/...`;
  /// those are served by the media hosts, not by the site host.
  String resolveBodyUrl(String url) {
    final value = url.trim();
    if (value.isEmpty) return value;

    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';

    final path = value.startsWith('/') ? value : '/$value';
    const previewPrefix = '/thumbnail/data';
    if (path.startsWith('$previewPrefix/')) {
      return '$previewBase${path.substring(previewPrefix.length)}';
    }
    if (path.startsWith('/data/')) {
      return '$mediaBase${path.substring('/data'.length)}';
    }
    return 'https://$host$path';
  }

  /// Resolves a [KemonoServer] from its [host], used for persistence/URLs.
  static KemonoServer? fromHost(String host) {
    for (final server in values) {
      if (server.host == host) return server;
    }
    return null;
  }
}
