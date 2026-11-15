import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/kemono_server.dart';

/// The persisted server configuration: the server list and the last selected
/// one.
class ServerState {
  const ServerState({required this.servers, required this.selectedHost});

  final List<KemonoServer> servers;

  /// Host of the server the user worked with last.
  final String selectedHost;
}

/// Persists the user's server configuration across app runs.
abstract interface class ServerStore {
  /// Returns null when nothing has been persisted yet or the stored value is
  /// unusable.
  Future<ServerState?> load();

  Future<void> save(ServerState state);
}

/// Stores the server configuration in the platform's shared preferences.
class SharedPreferencesServerStore implements ServerStore {
  /// Versioned key; bump it if the serialized shape ever changes.
  @visibleForTesting
  static const String serversKey = 'servers.v1';

  @visibleForTesting
  static const String selectedKey = 'servers.selected.v1';

  @override
  Future<ServerState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(serversKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;

      final servers = <KemonoServer>[];
      for (final entry in decoded) {
        final server = KemonoServer.tryParse(entry);
        if (server == null || servers.contains(server)) continue;
        servers.add(server);
      }
      if (servers.isEmpty) return null;

      return ServerState(
        servers: servers,
        selectedHost: prefs.getString(selectedKey) ?? servers.first.host,
      );
    } catch (error) {
      // A truncated or hand-edited value must not break the whole app.
      debugPrint('Could not read servers: $error');
      return null;
    }
  }

  @override
  Future<void> save(ServerState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      serversKey,
      jsonEncode([for (final server in state.servers) server.toJson()]),
    );
    await prefs.setString(selectedKey, state.selectedHost);
  }
}
