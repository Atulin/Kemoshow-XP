import '../../core/kemono_server.dart';
import '../../domain/models/media_item.dart';
import '../../domain/models/slideshow_source.dart';
import '../../domain/repositories/media_repositories.dart';
import '../models/creator.dart';
import '../models/post.dart';
import '../services/kemono_api_service.dart';
import '../services/media_host_resolver.dart';

/// Single source of truth for API data used by the app.
///
/// Caches the creator directory per server for the runtime of the app and
/// converts API posts into flattened [MediaItem]s. Media URLs are built with
/// the media host the server currently redirects to, so a stale configured
/// [KemonoServer.dataHost] heals itself instead of failing with HTTP 403.
class KemonoRepository implements SlideshowRepository, CreatorDirectory {
  KemonoRepository(this._api, {MediaHostResolver? mediaHostResolver})
    : _mediaHosts = mediaHostResolver ?? MediaHostResolver();

  final KemonoApiService _api;
  final MediaHostResolver _mediaHosts;

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
    required bool includeLinkedMedia,
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
      final mediaBase = await _resolveMediaBase(server, posts);
      items.addAll(
        MediaItem.flattenPosts(
          posts,
          mediaBase: mediaBase,
          previewBase: server.previewBase,
          includeLinkedMedia: includeLinkedMedia,
        ),
      );
      hasMore = posts.length >= KemonoApiService.pageSize;
      nextOffset += posts.length;

      if (posts.isEmpty) break;
    }

    return MediaPage(items: items, nextOffset: nextOffset, hasMore: hasMore);
  }

  /// The media base to build file URLs with, resolved against the media host
  /// the server currently redirects to.
  Future<String> _resolveMediaBase(
    KemonoServer server,
    List<Post> posts,
  ) async {
    for (final post in posts) {
      final sample = post.file?.path ?? _firstAttachmentPath(post);
      if (sample == null || sample.isEmpty) continue;
      final dataHost = await _mediaHosts.resolveDataHost(server, sample);
      return 'https://$dataHost/data';
    }
    return server.mediaBase;
  }

  static String? _firstAttachmentPath(Post post) {
    for (final attachment in post.attachments) {
      final path = attachment.path;
      if (path != null && path.isNotEmpty) return path;
    }
    return null;
  }

  /// Fetches the full post, including the body that post listings omit.
  ///
  /// Returns null when the post cannot be addressed, e.g. because the listing
  /// did not include its service or creator.
  Future<Post?> fetchPost({
    required KemonoServer server,
    required Post post,
  }) async {
    final service = post.service;
    final creatorId = post.user;
    if (service == null ||
        service.isEmpty ||
        creatorId == null ||
        creatorId.isEmpty) {
      return null;
    }
    final fetched = await _api.fetchPost(
      server: server,
      service: service,
      creatorId: creatorId,
      postId: post.id,
    );
    if (fetched == null) return null;
    return _rewriteBodyUrls(server, fetched);
  }

  /// Makes file links in the body absolute, using the currently valid media
  /// host. Other relative links are left for the body view to resolve against
  /// the site host.
  Future<Post> _rewriteBodyUrls(KemonoServer server, Post post) async {
    final content = post.content;
    if (content == null || !content.contains('/data')) return post;

    final sample =
        post.file?.path ??
        _firstAttachmentPath(post) ??
        _firstLinkedPath(content);
    if (sample == null) return post;

    final dataHost = await _mediaHosts.resolveDataHost(server, sample);
    final effective = dataHost == server.dataHost
        ? server
        : KemonoServer(
            host: server.host,
            dataHost: dataHost,
            previewHost: server.previewHost,
          );

    final rewritten = content.replaceAllMapped(_mediaPathPattern, (match) {
      final path = match[2]!;
      // `match[1]` is set for `/thumbnail/data/…` paths, which are served by
      // the preview host.
      final base = match[1] == null
          ? effective.mediaBase
          : effective.previewBase;
      return '$base/$path';
    });
    if (rewritten == content) return post;
    return PostMapper.fromMap({...post.toMap(), 'content': rewritten});
  }

  /// Matches `/data/…` and `/thumbnail/data/…` file paths inside a body.
  ///
  /// A single pass, so the `/data/` inside a rewritten `/thumbnail/data/` path
  /// is never matched twice.
  static final RegExp _mediaPathPattern = RegExp(
    r'(/thumbnail)?/data/([A-Za-z0-9._/-]+)',
  );

  /// The first `/data/…` file path linked from a body, used to trigger the
  /// media host redirect when the post itself has no file.
  static String? _firstLinkedPath(String content) {
    final match = RegExp(r'/data/([A-Za-z0-9._/-]+)').firstMatch(content);
    return match?.group(1);
  }

  /// Closes the API client. The repository is not usable afterwards.
  void dispose() {
    _api.close();
    _mediaHosts.dispose();
  }
}
