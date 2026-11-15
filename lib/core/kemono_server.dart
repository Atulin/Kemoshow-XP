/// A Kemono-type server the application can talk to.
///
/// Servers are user-configurable because these sites occasionally move to a
/// new domain. Media is not necessarily served from the same host as the API,
/// hence the separate [dataHost]. Posts that have not been archived completely
/// yet only serve a downscaled preview, which lives on [previewHost].
class KemonoServer {
  const KemonoServer({
    required this.host,
    required this.dataHost,
    required this.previewHost,
  });

  /// The bundled servers. New servers can be added by the user at runtime.
  static const KemonoServer pawchive = KemonoServer(
    host: 'pawchive.pw',
    dataHost: 'n2.pawchive.pw',
    previewHost: 'img.pawchive.pw',
  );
  static const KemonoServer kemono = KemonoServer(
    host: 'kemono.cr',
    dataHost: 'n4.kemono.cr',
    previewHost: 'img.kemono.cr',
  );
  static const KemonoServer coomer = KemonoServer(
    host: 'coomer.su',
    dataHost: 'n3.coomer.st',
    previewHost: 'img.coomer.st',
  );

  static const List<KemonoServer> bundledServers = [pawchive, kemono, coomer];

  static const KemonoServer defaultServer = pawchive;

  /// Host serving the web UI and API.
  final String host;

  /// Host serving media files under `/data/`.
  final String dataHost;

  /// Host serving preview images under `/thumbnail/data/`.
  final String previewHost;

  /// Matches a lowercase hostname such as `coomer.st` or `n3.coomer.st`.
  static final RegExp _hostPattern = RegExp(
    r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$',
  );

  /// Whether [value] looks like a usable hostname, e.g. `coomer.st`.
  static bool isValidHost(String value) => _hostPattern.hasMatch(value);

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

  /// Resolves a [KemonoServer] by its [host] within [servers].
  ///
  /// Used for persistence and URLs; comparisons ignore case.
  static KemonoServer? fromHost(
    String host, {
    List<KemonoServer> servers = bundledServers,
  }) {
    final value = host.trim().toLowerCase();
    for (final server in servers) {
      if (server.host.toLowerCase() == value) return server;
    }
    return null;
  }

  /// Serializes this server for the persisted configuration.
  Map<String, Object?> toJson() => {
    'host': host,
    'dataHost': dataHost,
    'previewHost': previewHost,
  };

  /// Parses a [toJson] map, returning null for malformed or empty entries.
  static KemonoServer? tryParse(Object? json) {
    if (json is! Map) return null;
    final host = _normalize(json['host']);
    final dataHost = _normalize(json['dataHost']);
    final previewHost = _normalize(json['previewHost']);
    if (host == null || dataHost == null || previewHost == null) return null;
    return KemonoServer(
      host: host,
      dataHost: dataHost,
      previewHost: previewHost,
    );
  }

  static String? _normalize(Object? value) {
    if (value is! String) return null;
    final host = value.trim().toLowerCase();
    return isValidHost(host) ? host : null;
  }

  @override
  bool operator ==(Object other) =>
      other is KemonoServer &&
      other.host.toLowerCase() == host.toLowerCase() &&
      other.dataHost.toLowerCase() == dataHost.toLowerCase() &&
      other.previewHost.toLowerCase() == previewHost.toLowerCase();

  @override
  int get hashCode => Object.hash(
    host.toLowerCase(),
    dataHost.toLowerCase(),
    previewHost.toLowerCase(),
  );

  @override
  String toString() => 'KemonoServer($host)';
}
