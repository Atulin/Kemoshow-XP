import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../../core/kemono_server.dart';
import '../../../../domain/models/media_item.dart';
import '../../../../domain/models/slideshow_source.dart';
import '../../../../domain/repositories/media_repositories.dart';

/// Drives the slideshow: owns the flattened media list, the pagination state
/// and the currently visible index.
class SlideshowViewModel extends ChangeNotifier {
  SlideshowViewModel(
    this._repository, {
    required this.source,
    required this.server,
    this.includeLinkedMedia = false,
  });

  /// How many media items before the end trigger a fetch of the next page.
  static const int prefetchThreshold = 5;

  final SlideshowRepository _repository;
  final SlideshowSource source;
  final KemonoServer server;

  /// Whether media files linked from post bodies are part of the slideshow.
  final bool includeLinkedMedia;

  final List<MediaItem> _items = [];
  final Set<String> _seenUrls = {};

  int _nextOffset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _initialAttemptFinished = false;
  bool _disposed = false;
  String? _error;
  int _currentIndex = 0;

  UnmodifiableListView<MediaItem> get items => UnmodifiableListView(_items);

  bool get isEmpty => _items.isEmpty;

  bool get isLoading => _isLoading;

  /// True while the very first page is being fetched.
  bool get isInitialLoading => _isLoading && !_initialAttemptFinished;

  bool get hasMore => _hasMore;

  String? get error => _error;

  int get currentIndex => _currentIndex;

  MediaItem? get current =>
      _items.isEmpty ? null : _items[_currentIndex.clamp(0, _items.length - 1)];

  /// Number of items after the current one that are already loaded.
  int get remainingAfterCurrent => _items.isEmpty
      ? 0
      : _items.length - 1 - _currentIndex.clamp(0, _items.length - 1);

  bool get isAtEnd => !_hasMore && _currentIndex >= _items.length - 1;

  /// Fetches the first page. Safe to call multiple times.
  Future<void> loadInitial() async {
    if (_initialAttemptFinished && !_isLoading && _items.isNotEmpty) return;
    await _loadMore();
  }

  /// Fetches the next page, if any. Errors are exposed through [error] and can
  /// be retried by calling this again.
  Future<void> loadMore() => _loadMore();

  Future<void> _loadMore() async {
    if (_disposed || _isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    _notify();

    var addedCount = 0;
    try {
      final page = await _repository.fetchMediaPage(
        server: server,
        source: source,
        offset: _nextOffset,
        includeLinkedMedia: includeLinkedMedia,
      );
      if (_disposed) return;

      _nextOffset = page.nextOffset;
      _hasMore = page.hasMore;

      for (final item in page.items) {
        if (_seenUrls.add(item.url)) {
          _items.add(item);
          addedCount++;
        }
      }

      // If the server handed back only duplicates, stop auto-prefetching.
      if (addedCount == 0 && page.hasMore) {
        _hasMore = false;
      }
    } catch (error) {
      if (_disposed) return;
      _error = error.toString();
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _initialAttemptFinished = true;
        _notify();
      }
    }

    if (!_disposed &&
        addedCount > 0 &&
        _hasMore &&
        remainingAfterCurrent <= prefetchThreshold) {
      unawaited(_loadMore());
    }
  }

  /// Called by the view when the visible page changes.
  void onPageChanged(int index) {
    if (index == _currentIndex) return;
    _currentIndex = index;
    _notify();

    if (remainingAfterCurrent <= prefetchThreshold) {
      unawaited(_loadMore());
    }
  }

  void retry() {
    if (_isLoading) return;
    _hasMore = true;
    unawaited(_loadMore());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
