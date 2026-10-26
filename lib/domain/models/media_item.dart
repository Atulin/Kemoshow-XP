import '../../data/models/post.dart';

/// Type of a flattened media item.
enum MediaKind { image, video }

/// A single entry of the slideshow: one file of one post.
class MediaItem {
  const MediaItem({
    required this.url,
    required this.name,
    required this.kind,
    required this.post,
    required this.isAttachment,
  });

  /// Absolute URL of the media file.
  final String url;

  /// Name of the file, used for accessibility and error messages.
  final String name;

  final MediaKind kind;

  /// Post this file belongs to, used for the slideshow header.
  final Post post;

  /// Whether this is one of the post's attachments rather than its primary
  /// file.
  final bool isAttachment;

  bool get isVideo => kind == MediaKind.video;

  /// Flattens [posts] into a linear list of media items, skipping files
  /// without a usable path.
  static List<MediaItem> flattenPosts(
    Iterable<Post> posts, {
    required String mediaBase,
  }) {
    final items = <MediaItem>[];
    for (final post in posts) {
      final primary = post.file;
      if (primary != null) {
        final item = _fromFile(primary, post, mediaBase, isAttachment: false);
        if (item != null) items.add(item);
      }
      for (final attachment in post.attachments) {
        final item = _fromFile(attachment, post, mediaBase, isAttachment: true);
        if (item != null) items.add(item);
      }
    }
    return items;
  }

  static MediaItem? _fromFile(
    PostFile file,
    Post post,
    String mediaBase, {
    required bool isAttachment,
  }) {
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    final base = mediaBase.endsWith('/')
        ? mediaBase.substring(0, mediaBase.length - 1)
        : mediaBase;
    final normalized = path.startsWith('/') ? path : '/$path';
    final name = file.fileName ?? normalized.split('/').last;
    return MediaItem(
      url: '$base$normalized',
      name: name,
      kind: kindFromName(name),
      post: post,
      isAttachment: isAttachment,
    );
  }

  static const _videoExtensions = {
    'mp4',
    'm4v',
    'webm',
    'mov',
    'mkv',
    'avi',
    'wmv',
    'flv',
    'mpg',
    'mpeg',
    'ts',
    'm3u8',
  };

  /// Classifies a file by its extension. Anything that is not a known video
  /// is treated as an image, which is the far more common case.
  static MediaKind kindFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return MediaKind.image;
    final extension = name.substring(dot + 1).toLowerCase();
    return _videoExtensions.contains(extension)
        ? MediaKind.video
        : MediaKind.image;
  }
}
