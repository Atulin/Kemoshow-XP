import 'package:dart_mappable/dart_mappable.dart';

part 'post.mapper.dart';

/// A single file attached to a [Post].
@MappableClass()
class PostFile with PostFileMappable {
  const PostFile({this.name, this.path});

  final String? name;

  /// Path relative to the media host, starting with `/`.
  final String? path;

  /// File name without directory, when the API only supplied a path.
  String? get fileName {
    final path = this.path;
    if (path == null || path.isEmpty) return name;
    final segments = path.split('/');
    return segments.isEmpty ? name : segments.last;
  }

  static const fromMap = PostFileMapper.fromMap;
}

/// A post as returned by `/api/v1/posts` and
/// `/api/v1/{service}/user/{creator_id}/posts`.
@MappableClass()
class Post with PostMappable {
  const Post({
    required this.id,
    this.user,
    this.service,
    this.title,
    this.content,
    this.file,
    this.attachments = const [],
    this.published,
    this.added,
    this.sharedFile = false,
  });

  final String id;

  /// Creator ID the post belongs to.
  final String? user;

  /// Service the post originates from.
  final String? service;

  final String? title;

  /// HTML body of the post. Not rendered by the slideshow, but useful for
  /// debugging and future features.
  final String? content;

  /// The post's primary file, if any.
  final PostFile? file;

  final List<PostFile> attachments;

  /// Timestamps are kept as raw strings: the API returns several different
  /// formats and occasionally empty values.
  final String? published;
  final String? added;

  @MappableField(key: 'shared_file')
  final bool sharedFile;

  /// Every file of the post, primary file first.
  List<PostFile> get allFiles => [
    if (file?.path != null || file?.name != null) file!,
    ...attachments,
  ];

  DateTime? get publishedDate =>
      published == null ? null : DateTime.tryParse(published!);

  static const fromMap = PostMapper.fromMap;
  static const fromJson = PostMapper.fromJson;
}

/// Paginated response of `/api/v1/posts`.
@MappableClass()
class PostSearchResponse with PostSearchResponseMappable {
  const PostSearchResponse({
    this.posts = const [],
    this.count = 0,
    this.trueCount = 0,
  });

  final List<Post> posts;
  final int count;

  @MappableField(key: 'true_count')
  final int trueCount;

  static const fromMap = PostSearchResponseMapper.fromMap;
}

/// Paginated response of `/api/v1/{service}/user/{creator_id}/posts`.
@MappableClass()
class CreatorPostsResponse with CreatorPostsResponseMappable {
  const CreatorPostsResponse({this.results = const [], this.props});

  final List<Post> results;
  final CreatorPostsProps? props;

  static const fromMap = CreatorPostsResponseMapper.fromMap;
}

@MappableClass()
class CreatorPostsProps with CreatorPostsPropsMappable {
  const CreatorPostsProps({this.count});

  /// Total number of posts of the creator, including ones without media.
  final int? count;

  static const fromMap = CreatorPostsPropsMapper.fromMap;
}
