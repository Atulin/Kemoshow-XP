import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/models/creator.dart';
import 'package:kemoshow/data/services/favourites_store.dart';
import 'package:kemoshow/domain/models/favourite.dart';
import 'package:kemoshow/domain/models/slideshow_source.dart';
import 'package:kemoshow/ui/features/favourites/view_models/favourites_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/in_memory_favourites_store.dart';

class _FailingFavouritesStore implements FavouritesStore {
  @override
  Future<List<Favourite>> load() async => throw StateError('unavailable');

  @override
  Future<void> save(List<Favourite> favourites) async {}
}

/// A store whose [load] only completes when the test says so, to exercise
/// mutations racing the initial read.
class _DelayedFavouritesStore implements FavouritesStore {
  final Completer<List<Favourite>> _load = Completer<List<Favourite>>();

  List<Favourite> saved = const [];
  int saveCount = 0;

  @override
  Future<List<Favourite>> load() => _load.future;

  @override
  Future<void> save(List<Favourite> favourites) async {
    saved = List.of(favourites);
    saveCount++;
  }

  void completeLoad(List<Favourite> favourites) => _load.complete(favourites);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Favourite', () {
    test('post searches round-trip through JSON', () {
      const favourite = PostSearchFavourite(KemonoServer.kemono, 'Cat');

      expect(favourite.title, 'Cat');
      expect(favourite.toSource(), const PostSearchSource('Cat'));
      expect(favourite.toJson(), {
        'kind': 'postSearch',
        'server': 'kemono.cr',
        'term': 'Cat',
      });

      final parsed = Favourite.fromJson(favourite.toJson());
      expect(parsed, favourite);
      expect(parsed?.toSource(), const PostSearchSource('Cat'));
    });

    test('compares post searches case-insensitively and per server', () {
      const favourite = PostSearchFavourite(KemonoServer.pawchive, 'Cat');

      expect(
        favourite,
        const PostSearchFavourite(KemonoServer.pawchive, 'cat'),
      );
      expect(
        favourite,
        isNot(const PostSearchFavourite(KemonoServer.kemono, 'cat')),
      );
    });

    test('authors round-trip and ignore the cached name for identity', () {
      const favourite = AuthorFavourite(
        server: KemonoServer.pawchive,
        id: '42',
        service: 'fanbox',
        name: 'Alice',
      );

      expect(favourite.title, 'Alice');
      expect(
        favourite.toSource(),
        // The cached name is irrelevant when opening the creator.
        const CreatorSource(Creator(id: '42', service: 'fanbox')),
      );
      expect(favourite.toJson(), {
        'kind': 'author',
        'server': 'pawchive.pw',
        'id': '42',
        'service': 'fanbox',
        'name': 'Alice',
      });

      final parsed = Favourite.fromJson({
        ...favourite.toJson(),
        'name': 'Renamed',
      });
      expect(parsed, favourite);
      expect(parsed?.title, 'Renamed');
    });

    test('falls back to the ID when an author has no name', () {
      const favourite = AuthorFavourite(
        server: KemonoServer.coomer,
        id: '7',
        service: 'onlyfans',
      );

      expect(favourite.title, '7');
      expect(favourite.toJson().containsKey('name'), isFalse);
    });

    test('rejects malformed data', () {
      expect(
        Favourite.fromJson({
          'kind': 'postSearch',
          'server': 'unknown.example',
          'term': 'cats',
        }),
        isNull,
      );
      expect(
        Favourite.fromJson({'kind': 'postSearch', 'server': 'pawchive.pw'}),
        isNull,
      );
      expect(
        Favourite.fromJson({
          'kind': 'postSearch',
          'server': 'pawchive.pw',
          'term': '   ',
        }),
        isNull,
      );
      expect(
        Favourite.fromJson({
          'kind': 'author',
          'server': 'pawchive.pw',
          'id': '1',
        }),
        isNull,
      );
      expect(
        Favourite.fromJson({'kind': 'other', 'server': 'pawchive.pw'}),
        isNull,
      );
    });
  });

  group('FavouritesController', () {
    test('starts empty before loading', () {
      final controller = FavouritesController(InMemoryFavouritesStore());
      addTearDown(controller.dispose);

      expect(controller.isLoaded, isFalse);
      expect(controller.favourites, isEmpty);
      expect(controller.isEmpty, isTrue);
    });

    test('loads and deduplicates persisted favourites', () async {
      const post = PostSearchFavourite(KemonoServer.pawchive, 'cats');
      const author = AuthorFavourite(
        server: KemonoServer.pawchive,
        id: '1',
        service: 'fanbox',
        name: 'Alice',
      );
      final store = InMemoryFavouritesStore([
        post,
        const PostSearchFavourite(KemonoServer.pawchive, 'CATS'),
        author,
      ]);
      final controller = FavouritesController(store);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(controller.favourites, [post, author]);
      expect(controller.isEmpty, isFalse);
    });

    test('keeps favourites starred while loading', () async {
      const post = PostSearchFavourite(KemonoServer.pawchive, 'cats');
      const author = AuthorFavourite(
        server: KemonoServer.pawchive,
        id: '1',
        service: 'fanbox',
        name: 'Alice',
      );
      final store = _DelayedFavouritesStore();
      final controller = FavouritesController(store);
      addTearDown(controller.dispose);

      final loading = controller.load();
      expect(controller.toggle(post), isTrue);
      store.completeLoad([author]);

      await loading;
      await pumpEventQueue();

      expect(controller.favourites, [post, author]);
      expect(store.saved, [post, author]);
    });

    test('adds newest first, toggles off and persists', () async {
      final store = InMemoryFavouritesStore();
      final controller = FavouritesController(store);
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      const post = PostSearchFavourite(KemonoServer.pawchive, 'cats');
      const author = AuthorFavourite(
        server: KemonoServer.pawchive,
        id: '1',
        service: 'fanbox',
        name: 'Alice',
      );

      expect(controller.toggle(post), isTrue);
      expect(controller.toggle(author), isTrue);
      expect(controller.favourites, [author, post]);
      expect(controller.contains(post), isTrue);

      // The same post search with a different case removes the saved entry.
      expect(
        controller.toggle(
          const PostSearchFavourite(KemonoServer.pawchive, 'CATS'),
        ),
        isFalse,
      );
      await pumpEventQueue();

      expect(controller.favourites, [author]);
      expect(controller.contains(post), isFalse);
      expect(store.favourites, [author]);
      expect(store.saveCount, 3);
      expect(notifications, 3);
    });

    test('remove ignores favourites that are not saved', () async {
      final store = InMemoryFavouritesStore();
      final controller = FavouritesController(store);
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.remove(const PostSearchFavourite(KemonoServer.pawchive, 'x'));
      await pumpEventQueue();

      expect(controller.favourites, isEmpty);
      expect(notifications, 0);
      expect(store.saveCount, 0);
    });

    test('falls back to an empty list when loading fails', () async {
      final controller = FavouritesController(_FailingFavouritesStore());
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(controller.favourites, isEmpty);
    });
  });

  group('SharedPreferencesFavouritesStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round-trips favourites', () async {
      const favourites = [
        PostSearchFavourite(KemonoServer.pawchive, 'cats'),
        AuthorFavourite(
          server: KemonoServer.coomer,
          id: '9',
          service: 'onlyfans',
          name: 'Zoe',
        ),
      ];
      final store = SharedPreferencesFavouritesStore();

      await store.save(favourites);

      expect(await store.load(), favourites);
    });

    test('returns an empty list for corrupt data', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesFavouritesStore.storageKey: '{not json',
      });

      expect(await SharedPreferencesFavouritesStore().load(), isEmpty);
    });

    test('skips malformed entries but keeps valid ones', () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesFavouritesStore.storageKey: jsonEncode([
          {'kind': 'postSearch', 'server': 'pawchive.pw', 'term': 'cats'},
          {'kind': 'postSearch', 'server': 'nowhere.example', 'term': 'x'},
          {'kind': 'author', 'server': 'pawchive.pw'},
          'nonsense',
        ]),
      });

      expect(await SharedPreferencesFavouritesStore().load(), [
        const PostSearchFavourite(KemonoServer.pawchive, 'cats'),
      ]);
    });
  });
}
