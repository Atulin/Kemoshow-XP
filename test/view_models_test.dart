import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/models/creator.dart';
import 'package:kemoshow/domain/models/media_item.dart';
import 'package:kemoshow/domain/models/slideshow_source.dart';
import 'package:kemoshow/domain/repositories/media_repositories.dart';
import 'package:kemoshow/ui/features/search/view_models/search_view_model.dart';
import 'package:kemoshow/ui/features/slideshow/view_models/slideshow_view_model.dart';

import 'package:kemoshow/data/models/post.dart';

MediaItem _item(int index) => MediaItem(
  url: 'https://n2.pawchive.pw/data/$index.jpg',
  name: '$index.jpg',
  kind: MediaKind.image,
  post: Post(id: '$index'),
  isAttachment: false,
);

MediaPage _page(int offset, int count, {required bool hasMore}) {
  return MediaPage(
    items: [for (var i = 0; i < count; i++) _item(offset + i)],
    nextOffset: offset + count,
    hasMore: hasMore,
  );
}

class _FakeSlideshowRepository implements SlideshowRepository {
  _FakeSlideshowRepository(this._page);

  final Future<MediaPage> Function(int offset) _page;
  final List<int> requestedOffsets = [];

  @override
  Future<MediaPage> fetchMediaPage({
    required KemonoServer server,
    required SlideshowSource source,
    required int offset,
  }) {
    requestedOffsets.add(offset);
    return _page(offset);
  }
}

class _FakeCreatorDirectory implements CreatorDirectory {
  _FakeCreatorDirectory({this.creatorsByServer = const {}});

  final Map<KemonoServer, List<Creator>> creatorsByServer;
  final List<KemonoServer> warmedUp = [];
  final Map<KemonoServer, int> calls = {};
  Object? error;

  @override
  Future<List<Creator>> creators(KemonoServer server) async {
    calls[server] = (calls[server] ?? 0) + 1;
    final error = this.error;
    if (error != null) throw error;
    return creatorsByServer[server] ?? const [];
  }

  @override
  void warmUpCreators(KemonoServer server) => warmedUp.add(server);
}

void main() {
  group('SlideshowViewModel', () {
    test(
      'loads the first page without prefetching when far from the end',
      () async {
        final repository = _FakeSlideshowRepository(
          (offset) async => _page(offset, 10, hasMore: true),
        );
        final viewModel = SlideshowViewModel(
          repository,
          source: const PostSearchSource('cat'),
          server: KemonoServer.pawchive,
        );
        addTearDown(viewModel.dispose);

        await viewModel.loadInitial();
        await pumpEventQueue();

        expect(viewModel.items, hasLength(10));
        expect(viewModel.hasMore, isTrue);
        expect(viewModel.isInitialLoading, isFalse);
        expect(repository.requestedOffsets, [0]);
      },
    );

    test('fetches the next page when only 5 items remain', () async {
      final repository = _FakeSlideshowRepository(
        (offset) async => _page(offset, 10, hasMore: offset < 50),
      );
      final viewModel = SlideshowViewModel(
        repository,
        source: const PostSearchSource('cat'),
        server: KemonoServer.pawchive,
      );
      addTearDown(viewModel.dispose);

      await viewModel.loadInitial();
      await pumpEventQueue();
      expect(repository.requestedOffsets, [0]);

      viewModel.onPageChanged(3); // 6 items left -> no fetch
      await pumpEventQueue();
      expect(repository.requestedOffsets, [0]);

      viewModel.onPageChanged(4); // 5 items left -> fetch
      await pumpEventQueue();

      expect(viewModel.items, hasLength(20));
      expect(repository.requestedOffsets, [0, 10]);
    });

    test('prefetches immediately when the first page is short', () async {
      final repository = _FakeSlideshowRepository((offset) async {
        if (offset == 0) {
          return _page(0, 3, hasMore: true);
        }
        return _page(offset, 3, hasMore: false);
      });
      final viewModel = SlideshowViewModel(
        repository,
        source: const CreatorSource(Creator(id: '1', service: 'fanbox')),
        server: KemonoServer.kemono,
      );
      addTearDown(viewModel.dispose);

      await viewModel.loadInitial();
      await pumpEventQueue();

      expect(viewModel.items, hasLength(6));
      expect(viewModel.hasMore, isFalse);
      expect(repository.requestedOffsets, [0, 3]);
    });

    test('deduplicates media by URL', () async {
      final repository = _FakeSlideshowRepository((offset) async {
        if (offset == 0) {
          return MediaPage(
            items: [_item(0), _item(1)],
            nextOffset: 2,
            hasMore: true,
          );
        }
        return MediaPage(
          items: [_item(1), _item(2)],
          nextOffset: 4,
          hasMore: false,
        );
      });
      final viewModel = SlideshowViewModel(
        repository,
        source: const PostSearchSource('cat'),
        server: KemonoServer.pawchive,
      );
      addTearDown(viewModel.dispose);

      await viewModel.loadInitial();
      await pumpEventQueue();
      viewModel.onPageChanged(1);
      await pumpEventQueue();

      expect(viewModel.items.map((item) => item.url), [
        'https://n2.pawchive.pw/data/0.jpg',
        'https://n2.pawchive.pw/data/1.jpg',
        'https://n2.pawchive.pw/data/2.jpg',
      ]);
    });

    test('exposes errors and recovers on retry', () async {
      var fail = true;
      final repository = _FakeSlideshowRepository((offset) async {
        if (fail) {
          fail = false;
          throw StateError('boom');
        }
        return _page(offset, 2, hasMore: false);
      });
      final viewModel = SlideshowViewModel(
        repository,
        source: const PostSearchSource('cat'),
        server: KemonoServer.pawchive,
      );
      addTearDown(viewModel.dispose);

      await viewModel.loadInitial();
      await pumpEventQueue();

      expect(viewModel.items, isEmpty);
      expect(viewModel.error, contains('boom'));
      expect(viewModel.isInitialLoading, isFalse);

      viewModel.retry();
      await pumpEventQueue();

      expect(viewModel.error, isNull);
      expect(viewModel.items, hasLength(2));
    });

    test('clamps current index when the list changes', () async {
      final repository = _FakeSlideshowRepository(
        (offset) async => _page(offset, 2, hasMore: false),
      );
      final viewModel = SlideshowViewModel(
        repository,
        source: const PostSearchSource('cat'),
        server: KemonoServer.pawchive,
      );
      addTearDown(viewModel.dispose);

      await viewModel.loadInitial();
      viewModel.onPageChanged(1);

      expect(viewModel.current?.name, '1.jpg');
      expect(viewModel.isAtEnd, isTrue);
    });
  });

  group('SearchViewModel', () {
    const creators = [
      Creator(id: '1', service: 'fanbox', name: 'Alice', favorited: 10),
      Creator(id: '2', service: 'fanbox', name: 'Bob', favorited: 50),
      Creator(id: '3', service: 'patreon', name: 'alice coop', favorited: 1),
    ];

    test('warms up the default server and shows popular authors', () async {
      final directory = _FakeCreatorDirectory(
        creatorsByServer: {KemonoServer.defaultServer: creators},
      );
      final viewModel = SearchViewModel(directory);
      addTearDown(viewModel.dispose);

      expect(directory.warmedUp, [KemonoServer.defaultServer]);
      await pumpEventQueue();

      expect(viewModel.hasCreators, isTrue);
      expect(viewModel.isLoadingCreators, isFalse);
      expect(viewModel.suggestions.map((creator) => creator.name), [
        'Bob',
        'Alice',
        'alice coop',
      ]);
    });

    test('filters suggestions as the query changes', () async {
      final directory = _FakeCreatorDirectory(
        creatorsByServer: {KemonoServer.defaultServer: creators},
      );
      final viewModel = SearchViewModel(directory);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.updateQuery('alice');
      expect(viewModel.suggestions.map((creator) => creator.id), ['1', '3']);

      viewModel.updateQuery('BOB');
      expect(viewModel.suggestions.single.id, '2');

      viewModel.updateQuery('zzz');
      expect(viewModel.suggestions, isEmpty);
    });

    test('resolves exact names, IDs and unique matches', () async {
      final directory = _FakeCreatorDirectory(
        creatorsByServer: {KemonoServer.defaultServer: creators},
      );
      final viewModel = SearchViewModel(directory);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      expect(viewModel.resolveCreator('Alice')?.id, '1');
      expect(viewModel.resolveCreator('2')?.name, 'Bob');
      expect(viewModel.resolveCreator('alice coop')?.id, '3');
      expect(viewModel.resolveCreator('alice co')?.id, '3');
      expect(viewModel.resolveCreator('nobody'), isNull);
      expect(viewModel.queryError, isNotNull);
    });

    test('validates post search queries', () async {
      final directory = _FakeCreatorDirectory();
      final viewModel = SearchViewModel(directory);
      addTearDown(viewModel.dispose);

      expect(viewModel.buildPostSearchSource('ab'), isNull);
      expect(viewModel.queryError, isNotNull);

      final source = viewModel.buildPostSearchSource('  abc  ');
      expect(source, const PostSearchSource('abc'));
      expect(viewModel.queryError, isNull);
    });

    test('caches creator lists per server', () async {
      final directory = _FakeCreatorDirectory(
        creatorsByServer: {
          KemonoServer.defaultServer: creators,
          KemonoServer.kemono: const [
            Creator(id: '9', service: 'fanbox', name: 'Kemono Only'),
          ],
        },
      );
      final viewModel = SearchViewModel(directory);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      viewModel.selectServer(KemonoServer.kemono);
      await pumpEventQueue();
      expect(viewModel.suggestions.single.name, 'Kemono Only');

      viewModel.selectServer(KemonoServer.defaultServer);
      await pumpEventQueue();
      expect(viewModel.suggestions.first.name, 'Bob');

      expect(directory.calls[KemonoServer.defaultServer], 1);
      expect(directory.calls[KemonoServer.kemono], 1);
      expect(directory.warmedUp, contains(KemonoServer.kemono));
    });

    test('exposes creator errors and retries', () async {
      final directory = _FakeCreatorDirectory(
        creatorsByServer: {KemonoServer.defaultServer: creators},
      )..error = StateError('offline');
      final viewModel = SearchViewModel(directory);
      addTearDown(viewModel.dispose);
      await pumpEventQueue();

      expect(viewModel.creatorsError, contains('offline'));
      expect(viewModel.hasCreators, isFalse);

      directory.error = null;
      viewModel.retryCreators();
      await pumpEventQueue();

      expect(viewModel.creatorsError, isNull);
      expect(viewModel.suggestions, isNotEmpty);
      expect(directory.calls[KemonoServer.defaultServer], 2);
    });
  });
}
