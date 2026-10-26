import '../../core/kemono_server.dart';
import '../../data/models/creator.dart';
import 'slideshow_source.dart';

/// A post search or author the user starred for quick access.
///
/// Favourites are scoped to a [KemonoServer]: the same creator ID can exist on
/// every server, and a search term only makes sense against one of them.
sealed class Favourite {
  const Favourite(this.server);

  final KemonoServer server;

  /// Primary text shown in the favourites list.
  String get title;

  /// The slideshow source this favourite opens.
  SlideshowSource toSource();

  Map<String, Object?> toJson();

  /// Parses a [toJson] map. Returns null for unknown or malformed entries so a
  /// partially corrupt store cannot hide the valid favourites around it.
  static Favourite? fromJson(Map<String, Object?> json) {
    final serverValue = json['server'];
    if (serverValue is! String) return null;
    final server = KemonoServer.fromHost(serverValue);
    if (server == null) return null;

    switch (json['kind']) {
      case 'postSearch':
        final term = json['term'];
        if (term is! String) return null;
        final trimmed = term.trim();
        if (trimmed.isEmpty) return null;
        return PostSearchFavourite(server, trimmed);
      case 'author':
        final id = json['id'];
        final service = json['service'];
        if (id is! String || id.isEmpty) return null;
        if (service is! String || service.isEmpty) return null;
        final name = json['name'];
        return AuthorFavourite(
          server: server,
          id: id,
          service: service,
          name: name is String && name.trim().isNotEmpty ? name : null,
        );
      default:
        return null;
    }
  }
}

/// A free-text post search (`/api/v1/posts?q=...`).
class PostSearchFavourite extends Favourite {
  const PostSearchFavourite(super.server, this.term);

  final String term;

  @override
  String get title => term;

  @override
  SlideshowSource toSource() => PostSearchSource(term);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'postSearch',
    'server': server.host,
    'term': term,
  };

  @override
  bool operator ==(Object other) =>
      other is PostSearchFavourite &&
      other.server == server &&
      other.term.toLowerCase() == term.toLowerCase();

  @override
  int get hashCode => Object.hash(server, term.toLowerCase());

  @override
  String toString() => 'PostSearchFavourite(${server.host}, "$term")';
}

/// All posts of a single creator, identified by [service] and [id].
class AuthorFavourite extends Favourite {
  const AuthorFavourite({
    required KemonoServer server,
    required this.id,
    required this.service,
    this.name,
  }) : super(server);

  final String id;
  final String service;

  /// Cached display name, so the favourites list works before the creator
  /// directory for the server has been loaded.
  final String? name;

  String get displayName {
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty ? id : trimmed;
  }

  Creator get creator => Creator(id: id, service: service, name: name);

  @override
  String get title => displayName;

  @override
  SlideshowSource toSource() => CreatorSource(creator);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'author',
    'server': server.host,
    'id': id,
    'service': service,
    if (name != null) 'name': name,
  };

  @override
  bool operator ==(Object other) =>
      other is AuthorFavourite &&
      other.server == server &&
      other.id == id &&
      other.service == service;

  @override
  int get hashCode => Object.hash(server, id, service);

  @override
  String toString() =>
      'AuthorFavourite(${server.host}, $service/$id, "$displayName")';
}
