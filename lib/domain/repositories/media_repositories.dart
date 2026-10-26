import '../../core/kemono_server.dart';
import '../../data/models/creator.dart';
import '../models/media_item.dart';
import '../models/slideshow_source.dart';

/// One page of flattened media, plus the pagination state needed for the next
/// request.
class MediaPage {
  const MediaPage({
    required this.items,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<MediaItem> items;

  /// Offset (in posts, not media items) to use for the next request.
  final int nextOffset;

  final bool hasMore;
}

/// Feeds the slideshow.
abstract interface class SlideshowRepository {
  Future<MediaPage> fetchMediaPage({
    required KemonoServer server,
    required SlideshowSource source,
    required int offset,
  });
}

/// Provides the creator list used for author search autocomplete.
abstract interface class CreatorDirectory {
  Future<List<Creator>> creators(KemonoServer server);

  /// Starts fetching [server]'s creator list without waiting for the result.
  void warmUpCreators(KemonoServer server);
}
