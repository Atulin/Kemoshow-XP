import '../../core/kemono_server.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/slideshow_source.dart';
import '../../domain/repositories/media_repositories.dart';
import '../models/creator.dart';
import '../models/post.dart';
import '../services/kemono_api_service.dart';

/// Single source of truth for API data used by the app.
///
/// Caches the creator directory per server for the runtime of the app and
/// converts API posts into flattened [MediaItem]s.
class KemonoRepository implements SlideshowRepository, CreatorDirectory {
  KemonoRepository(this._api);

  final KemonoApiService _api;

  /// Maximum number of post pages fetched in one [fetchMediaPage] call. Pages
  /// without any media are skipped transparently, but this bound prevents a
  /// misbehaving server from spinning forever.
  static const int _maxPagesPerRequest = 5;

  final Map<KemonoServer, Future<List<Creator>>> _creatorCache = {};

  @override
  Future<List<Creator>> creators(KemonoServer server) {
    final cached = _creatorCache[server];
    if (cached != null) return cached;

    late final Future<List<Creator>> future;
    future = _api.fetchCreators(server: server).onError<List<Creator>>((
      Object error,
      StackTrace stackTrace,
    ) {
      // Never cache a failed request: the next caller should retry.
      if (identical(_creatorCache[server], future)) {
        _creatorCache.remove(server);
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _creatorCache[server] = future;
    return future;
  }

  @override
  void warmUpCreators(KemonoServer server) {
    creators(server).then<void>((_) {}, onError: (Object _) {});
  }

  @override
  Future<MediaPage> fetchMediaPage({
    required KemonoServer server,
    required SlideshowSource source,
    required int offset,
  }) async {
    final items = <MediaItem>[];
    var nextOffset = offset;
    var hasMore = true;
    var pagesFetched = 0;

    while (items.isEmpty && hasMore && pagesFetched < _maxPagesPerRequest) {
      final List<Post> posts;
      switch (source) {
        case PostSearchSource(:final term):
          posts = await _api.fetchPosts(
            server: server,
            query: term,
            offset: nextOffset,
          );
        case CreatorSource(:final creator):
          posts = await _api.fetchCreatorPosts(
            server: server,
            service: creator.service,
            creatorId: creator.id,
            offset: nextOffset,
          );
      }

      pagesFetched++;
      items.addAll(MediaItem.flattenPosts(posts, mediaBase: server.mediaBase));
      hasMore = posts.length >= KemonoApiService.pageSize;
      nextOffset += posts.length;

      if (posts.isEmpty) break;
    }

    return MediaPage(items: items, nextOffset: nextOffset, hasMore: hasMore);
  }

  /// Closes the API client. The repository is not usable afterwards.
  void dispose() => _api.close();
}
