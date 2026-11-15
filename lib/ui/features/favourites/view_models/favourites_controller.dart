import 'package:flutter/foundation.dart';

import '../../../../core/kemono_server.dart';
import '../../../../data/services/favourites_store.dart';
import '../../../../domain/models/favourite.dart';

/// Exposes the user's favourites to the UI and persists every change.
///
/// Newest favourites are kept first so the most recently starred entry is the
/// quickest to reach.
class FavouritesController extends ChangeNotifier {
  FavouritesController(this._store);

  final FavouritesStore _store;

  List<Favourite> _favourites = const [];
  bool _loaded = false;
  bool _mutatedBeforeLoad = false;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();

  List<Favourite> get favourites => _favourites;

  bool get isLoaded => _loaded;

  bool get isEmpty => _favourites.isEmpty;

  /// Whether [favourite] is saved. Equality is server-scoped and ignores the
  /// case of post search terms and the cached author name.
  bool contains(Favourite favourite) => _favourites.contains(favourite);

  /// Reads the persisted favourites. Failures fall back to an empty list.
  ///
  /// [servers] is the user's configured server list; favourites pointing to a
  /// removed server are dropped.
  Future<void> load({
    List<KemonoServer> servers = KemonoServer.bundledServers,
  }) async {
    List<Favourite> loaded;
    try {
      loaded = _deduplicate(await _store.load(servers: servers));
    } catch (error) {
      debugPrint('Could not load favourites: $error');
      loaded = const [];
    }
    if (_disposed) return;
    if (_mutatedBeforeLoad) {
      // Keep anything starred while the read was in flight and rewrite the
      // merged list, since the early write may have replaced the stored one.
      final merged = <Favourite>[..._favourites];
      for (final favourite in loaded) {
        if (!merged.contains(favourite)) merged.add(favourite);
      }
      _favourites = List.unmodifiable(merged);
      _persist();
    } else {
      _favourites = loaded;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Adds [favourite] if it is not saved yet, otherwise removes it. Returns
  /// whether it is a favourite afterwards.
  bool toggle(Favourite favourite) {
    if (contains(favourite)) {
      remove(favourite);
      return false;
    }
    _favourites = List.unmodifiable([favourite, ..._favourites]);
    _mutatedBeforeLoad = !_loaded;
    _persist();
    notifyListeners();
    return true;
  }

  void remove(Favourite favourite) {
    if (!contains(favourite)) return;
    _favourites = List.unmodifiable([
      for (final entry in _favourites)
        if (entry != favourite) entry,
    ]);
    _mutatedBeforeLoad = !_loaded;
    _persist();
    notifyListeners();
  }

  /// Moves every favourite saved on [oldServer] over to [newServer], used when
  /// a server is renamed.
  void updateServer(KemonoServer oldServer, KemonoServer newServer) {
    if (oldServer == newServer) return;
    if (!_favourites.any((favourite) => favourite.server == oldServer)) {
      return;
    }
    _favourites = _deduplicate([
      for (final favourite in _favourites)
        favourite.server == oldServer
            ? favourite.withServer(newServer)
            : favourite,
    ]);
    _persist();
    notifyListeners();
  }

  /// Removes every favourite saved on [server], used when a server is removed.
  void removeServer(KemonoServer server) {
    if (!_favourites.any((favourite) => favourite.server == server)) return;
    _favourites = List.unmodifiable([
      for (final favourite in _favourites)
        if (favourite.server != server) favourite,
    ]);
    _persist();
    notifyListeners();
  }

  /// Writes are chained so that a slow write cannot resurrect an old value.
  void _persist() {
    final snapshot = _favourites;
    _writes = _writes.then((_) async {
      try {
        await _store.save(snapshot);
      } catch (error) {
        debugPrint('Could not save favourites: $error');
      }
    });
  }

  static List<Favourite> _deduplicate(Iterable<Favourite> favourites) {
    final unique = <Favourite>[];
    for (final favourite in favourites) {
      if (!unique.contains(favourite)) unique.add(favourite);
    }
    return List.unmodifiable(unique);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
