import 'package:flutter/foundation.dart';

import '../../../../data/services/server_store.dart';
import '../../../../core/kemono_server.dart';

/// Exposes the user's server list and the selected server to the UI, and
/// persists every change.
///
/// Bundled servers are used until the persisted configuration has been read;
/// if a server was removed in an earlier run, the persisted selection falls
/// back to the first remaining server.
class ServerController extends ChangeNotifier {
  ServerController([this._store]);

  final ServerStore? _store;

  List<KemonoServer> _servers = KemonoServer.bundledServers;
  KemonoServer _selected = KemonoServer.defaultServer;
  bool _loaded = false;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();

  List<KemonoServer> get servers => _servers;

  KemonoServer get selectedServer => _selected;

  /// Whether the persisted configuration has been read. Until then the bundled
  /// defaults are used.
  bool get isLoaded => _loaded;

  /// Reads the persisted configuration. Failures fall back to the defaults.
  Future<void> load() async {
    ServerState? state;
    try {
      state = await _store?.load();
    } catch (error) {
      debugPrint('Could not load servers: $error');
    }
    if (_disposed) return;

    if (state != null && state.servers.isNotEmpty) {
      _servers = List.unmodifiable(state.servers);
      _selected =
          KemonoServer.fromHost(state.selectedHost, servers: _servers) ??
          _servers.first;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Whether [server] is part of the list.
  bool containsServer(KemonoServer server) => _servers.contains(server);

  /// Whether a server with the same site [host] is already configured.
  bool containsHost(String host) {
    final value = host.trim().toLowerCase();
    return _servers.any((server) => server.host.toLowerCase() == value);
  }

  /// Selects [server]. Returns whether the selection changed.
  bool select(KemonoServer server) {
    if (server == _selected || !containsServer(server)) return false;
    _selected = server;
    _persist();
    notifyListeners();
    return true;
  }

  /// Adds [server] unless a server with the same site host already exists.
  bool add(KemonoServer server) {
    if (containsHost(server.host)) return false;
    _servers = List.unmodifiable([..._servers, server]);
    _persist();
    notifyListeners();
    return true;
  }

  /// Replaces [oldServer] with [next]. Returns false when [next] would use the
  /// site host of another server or [oldServer] is unknown.
  bool update(KemonoServer oldServer, KemonoServer next) {
    final index = _servers.indexOf(oldServer);
    if (index < 0) return false;
    final duplicate = _servers.any(
      (server) =>
          server != oldServer &&
          server.host.toLowerCase() == next.host.toLowerCase(),
    );
    if (duplicate) return false;

    final servers = [..._servers]..[index] = next;
    _servers = List.unmodifiable(servers);
    if (_selected == oldServer) _selected = next;
    _persist();
    notifyListeners();
    return true;
  }

  /// Removes [server]. Returns false when it is the last remaining server or
  /// unknown.
  bool remove(KemonoServer server) {
    if (_servers.length <= 1 || !containsServer(server)) return false;
    final servers = [..._servers]..removeWhere((entry) => entry == server);
    _servers = List.unmodifiable(servers);
    if (_selected == server) _selected = servers.first;
    _persist();
    notifyListeners();
    return true;
  }

  /// Writes are chained so that a slow write cannot resurrect an old value.
  void _persist() {
    final store = _store;
    if (store == null) return;
    final snapshot = ServerState(
      servers: _servers,
      selectedHost: _selected.host,
    );
    _writes = _writes.then((_) async {
      try {
        await store.save(snapshot);
      } catch (error) {
        debugPrint('Could not save servers: $error');
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
