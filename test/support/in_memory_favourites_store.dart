import 'package:kemoshow/data/services/favourites_store.dart';
import 'package:kemoshow/domain/models/favourite.dart';

/// In-memory [FavouritesStore] for tests.
class InMemoryFavouritesStore implements FavouritesStore {
  InMemoryFavouritesStore([List<Favourite>? initial])
    : favourites = [...?initial];

  List<Favourite> favourites;
  int saveCount = 0;

  @override
  Future<List<Favourite>> load() async => List.of(favourites);

  @override
  Future<void> save(List<Favourite> value) async {
    favourites = List.of(value);
    saveCount++;
  }
}
