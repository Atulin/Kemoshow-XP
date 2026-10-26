/// The Kemono-type servers supported by the application.
///
/// Media is not necessarily served from the same host as the API, hence the
/// separate [dataHost].
enum KemonoServer {
  pawchive(host: 'pawchive.pw', dataHost: 'n2.pawchive.pw'),
  kemono(host: 'kemono.cr', dataHost: 'n4.kemono.cr'),
  coomer(host: 'coomer.su', dataHost: 'n3.coomer.st');

  const KemonoServer({required this.host, required this.dataHost});

  /// Host serving the web UI and API.
  final String host;

  /// Host serving media files under `/data/`.
  final String dataHost;

  static const KemonoServer defaultServer = KemonoServer.pawchive;

  /// Base URL of the API, e.g. `https://pawchive.pw/api`.
  Uri get apiBase => Uri.https(host, '/api');

  /// Prefix that media paths from the API are appended to.
  String get mediaBase => 'https://$dataHost/data';

  /// Human readable name, used in the server picker.
  String get label => host;

  /// Resolves a [KemonoServer] from its [host], used for persistence/URLs.
  static KemonoServer? fromHost(String host) {
    for (final server in values) {
      if (server.host == host) return server;
    }
    return null;
  }
}
