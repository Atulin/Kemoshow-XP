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
    this.previewUrl,
  });

  /// Absolute URL of the media file.
  final String url;

  /// Downscaled preview of [url], when the server offers one.
  ///
  /// Posts that are not archived completely yet serve a 404 for [url] but do
  /// provide a preview, which the slideshow uses as a fallback.
  final String? previewUrl;

  /// Name of the file, used for accessibility and error messages.
  final String name;

  final MediaKind kind;

  /// Post this file belongs to, used for the slideshow header.
  final Post post;

  /// Whether this is one of the post's attachments rather than its primary
  /// file or a link found in its body.
  final bool isAttachment;

  bool get isVideo => kind == MediaKind.video;

  /// Flattens [posts] into a linear list of media items, skipping files
  /// without a usable path and files that cannot be shown, such as archives.
  ///
  /// When [includeLinkedMedia] is set, links to media files found in the post
  /// body (for example `https://files.example/movie.mp4`) are added after the
  /// post's own files and attachments.
  ///
  /// [previewBase] is the prefix of the server's downscaled previews; when
  /// given, images get a [MediaItem.previewUrl] to fall back to.
  static List<MediaItem> flattenPosts(
    Iterable<Post> posts, {
    required String mediaBase,
    String? previewBase,
    bool includeLinkedMedia = false,
  }) {
    final items = <MediaItem>[];
    final seenUrls = <String>{};

    void add(MediaItem? item) {
      if (item == null) return;
      if (seenUrls.add(item.url)) items.add(item);
    }

    for (final post in posts) {
      if (post.file != null) {
        add(
          _fromFile(
            post.file!,
            post,
            mediaBase,
            previewBase: previewBase,
            isAttachment: false,
          ),
        );
      }
      for (final attachment in post.attachments) {
        add(
          _fromFile(
            attachment,
            post,
            mediaBase,
            previewBase: previewBase,
            isAttachment: true,
          ),
        );
      }
      if (includeLinkedMedia) {
        for (final url in mediaUrlsInHtml(post.content)) {
          add(_fromUrl(url, post));
        }
      }
    }
    return items;
  }

  static MediaItem? _fromFile(
    PostFile file,
    Post post,
    String mediaBase, {
    String? previewBase,
    required bool isAttachment,
  }) {
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    final base = _withoutTrailingSlash(mediaBase);
    final normalized = path.startsWith('/') ? path : '/$path';
    final name = file.fileName ?? normalized.split('/').last;
    if (_isNonMediaFile(name)) return null;
    final kind = kindFromName(name);
    return MediaItem(
      url: '$base$normalized',
      previewUrl: previewBase == null || kind != MediaKind.image
          ? null
          : '${_withoutTrailingSlash(previewBase)}$normalized',
      name: name,
      kind: kind,
      post: post,
      isAttachment: isAttachment,
    );
  }

  static String _withoutTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static MediaItem _fromUrl(String url, Post post) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments ?? const <String>[];
    final rawName = segments.isEmpty ? '' : segments.last;
    String name;
    try {
      name = Uri.decodeComponent(rawName);
    } on ArgumentError {
      name = rawName;
    }
    return MediaItem(
      url: url,
      name: name.isEmpty ? url : name,
      kind: kindFromName(name),
      post: post,
      isAttachment: false,
    );
  }

  static const _imageExtensions = {
    'jpg',
    'jpeg',
    'jfif',
    'png',
    'gif',
    'webp',
    'avif',
    'bmp',
    'apng',
    'heic',
    'heif',
  };

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

  static const _mediaExtensions = {..._imageExtensions, ..._videoExtensions};

  /// Extensions that are known not to be renderable by the slideshow.
  ///
  /// Archives, documents, audio files and similar attachments are common in
  /// post files; they would only ever show the broken-image state.
  static const _nonMediaExtensions = {
    // Archives
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'tgz',
    'bz2',
    'tbz2',
    'xz',
    'txz',
    'zst',
    'lz',
    'lzma',
    'iso',
    'cab',
    'arj',
    // Documents and data
    'pdf',
    'txt',
    'rtf',
    'doc',
    'docx',
    'odt',
    'xls',
    'xlsx',
    'csv',
    'ppt',
    'pptx',
    'epub',
    // Audio
    'mp3',
    'wav',
    'flac',
    'ogg',
    'oga',
    'opus',
    'm4a',
    'aac',
    'wma',
    'aiff',
    // Other binaries that are not images or videos
    'psd',
    'clip',
    'sai',
    'exe',
    'apk',
    'dmg',
    'torrent',
  };

  static final RegExp _urlPattern = RegExp(
    r'''(?:https?:)?//[^\s"'<>`]+''',
    caseSensitive: false,
  );

  /// Links to media files contained in a post body.
  ///
  /// Only absolute (or protocol-relative) links with a known image or video
  /// extension are returned; the URLs are normalized and duplicates removed.
  static Iterable<String> mediaUrlsInHtml(String? html) sync* {
    if (html == null || html.isEmpty) return;

    final seen = <String>{};
    for (final match in _urlPattern.allMatches(html)) {
      final url = _normalizeUrl(match.group(0)!);
      if (url == null) continue;
      if (!_hasMediaExtension(url)) continue;
      if (seen.add(url)) yield url;
    }
  }

  /// Whether [url] points directly at a file with a known media extension.
  static bool isMediaUrl(String url) {
    final normalized = _normalizeUrl(url);
    return normalized != null && _hasMediaExtension(normalized);
  }

  /// Classifies a file by its extension. Anything that is not a known video
  /// is treated as an image, which is the far more common case.
  static MediaKind kindFromName(String name) {
    final extension = _extensionOf(name);
    return extension != null && _videoExtensions.contains(extension)
        ? MediaKind.video
        : MediaKind.image;
  }

  /// Turns a raw match from a post body into an absolute URL, or null when it
  /// is not a usable HTTP(S) URL.
  static String? _normalizeUrl(String raw) {
    var value = raw.replaceAll('&amp;', '&');
    // Links are often followed by punctuation in running text.
    value = value.replaceFirst(RegExp(r'''[.,;:!?)\]}"']+$'''), '');
    if (value.isEmpty) return null;

    if (value.startsWith('//')) {
      value = 'https:$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    if (uri.host.isEmpty) return null;
    return value;
  }

  static bool _hasMediaExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return false;
    final extension = _extensionOf(segments.last);
    return extension != null && _mediaExtensions.contains(extension);
  }

  static bool _isNonMediaFile(String name) {
    final extension = _extensionOf(name);
    return extension != null && _nonMediaExtensions.contains(extension);
  }

  static String? _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }
}
