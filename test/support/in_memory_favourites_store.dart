import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/services/favourites_store.dart';
import 'package:kemoshow/domain/models/favourite.dart';

/// In-memory [FavouritesStore] for tests.
class InMemoryFavouritesStore implements FavouritesStore {
  InMemoryFavouritesStore([List<Favourite>? initial])
    : favourites = [...?initial];

  List<Favourite> favourites;
  int saveCount = 0;
  List<Favourite>? lastSaved;

  @override
  Future<List<Favourite>> load({
    List<KemonoServer> servers = KemonoServer.bundledServers,
  }) async => List.of(favourites);

  @override
  Future<void> save(List<Favourite> value) async {
    favourites = List.of(value);
    lastSaved = List.of(value);
    saveCount++;
  }
}
