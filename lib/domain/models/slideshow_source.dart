import '../../data/models/creator.dart';

/// Describes where the slideshow pulls its posts from.
sealed class SlideshowSource {
  const SlideshowSource();

  /// Title shown in the slideshow header.
  String get title;
}

/// Free-text post search (`/api/v1/posts?q=...`).
class PostSearchSource extends SlideshowSource {
  const PostSearchSource(this.term);

  final String term;

  @override
  String get title => term;

  @override
  bool operator ==(Object other) =>
      other is PostSearchSource && other.term == term;

  @override
  int get hashCode => term.hashCode;
}

/// All posts of a single creator.
class CreatorSource extends SlideshowSource {
  const CreatorSource(this.creator);

  final Creator creator;

  @override
  String get title => creator.displayName;

  @override
  bool operator ==(Object other) =>
      other is CreatorSource &&
      other.creator.id == creator.id &&
      other.creator.service == creator.service;

  @override
  int get hashCode => Object.hash(creator.id, creator.service);
}
