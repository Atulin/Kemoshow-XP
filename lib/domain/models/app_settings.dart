/// User-configurable behaviour of the app, persisted between runs.
class AppSettings {
  AppSettings({
    int preloadCount = defaultPreloadCount,
    this.scanPostContent = false,
  }) : preloadCount = preloadCount < minPreloadCount
           ? minPreloadCount
           : (preloadCount > maxPreloadCount ? maxPreloadCount : preloadCount);

  static const int minPreloadCount = 0;
  static const int maxPreloadCount = 10;
  static const int defaultPreloadCount = 2;

  /// How many upcoming media items are preloaded in the slideshow.
  final int preloadCount;

  /// Whether direct media links found in post bodies are added to the
  /// slideshow in addition to the post's files and attachments.
  final bool scanPostContent;

  AppSettings copyWith({int? preloadCount, bool? scanPostContent}) {
    return AppSettings(
      preloadCount: preloadCount ?? this.preloadCount,
      scanPostContent: scanPostContent ?? this.scanPostContent,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.preloadCount == preloadCount &&
      other.scanPostContent == scanPostContent;

  @override
  int get hashCode => Object.hash(preloadCount, scanPostContent);

  @override
  String toString() =>
      'AppSettings(preloadCount: $preloadCount, '
      'scanPostContent: $scanPostContent)';
}
