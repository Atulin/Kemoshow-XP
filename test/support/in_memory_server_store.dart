import 'package:kemoshow/data/services/server_store.dart';

/// In-memory [ServerStore] for tests.
class InMemoryServerStore implements ServerStore {
  InMemoryServerStore([this._initial]);

  ServerState? _initial;
  int saveCount = 0;

  @override
  Future<ServerState?> load() async => _initial;

  @override
  Future<void> save(ServerState state) async {
    _initial = ServerState(
      servers: List.of(state.servers),
      selectedHost: state.selectedHost,
    );
    saveCount++;
  }
}
