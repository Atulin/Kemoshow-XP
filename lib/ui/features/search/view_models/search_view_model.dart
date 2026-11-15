import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/kemono_server.dart';
import '../../../../data/models/creator.dart';
import '../../../../domain/models/slideshow_source.dart';
import '../../../../domain/repositories/media_repositories.dart';
import '../../servers/view_models/server_controller.dart';

/// What the search page is searching for.
enum SearchMode { posts, creators }

/// Owns the state of the search screen: selected server, search mode, the
/// creator directory for autocomplete and validation of the entered query.
///
/// The selected server lives in [ServerController] so it is shared with the
/// server management dialog and persisted across runs.
class SearchViewModel extends ChangeNotifier {
  SearchViewModel(this._repository, [ServerController? servers])
    : _servers = servers ?? ServerController(),
      _ownsServers = servers == null {
    _servers.addListener(_handleServersChanged);
    _selectedHost = _servers.selectedServer.host;
    // Start fetching the default server's creator directory immediately so
    // author autocomplete is ready by the time the user switches modes.
    _repository.warmUpCreators(_servers.selectedServer);
    unawaited(_loadCreators());
  }

  static const int maxSuggestions = 40;
  static const int minPostQueryLength = 3;

  final CreatorDirectory _repository;
  final ServerController _servers;

  /// Whether this view model created [_servers] itself and has to dispose it.
  final bool _ownsServers;

  /// Host of the server the current creator list belongs to.
  String _selectedHost = KemonoServer.defaultServer.host;

  final Map<KemonoServer, List<Creator>> _creatorsByServer = {};
  final Map<KemonoServer, List<Creator>> _popularByServer = {};

  SearchMode _mode = SearchMode.posts;
  String _query = '';
  String? _queryError;

  List<Creator> _creators = const [];
  List<Creator> _suggestions = const [];
  List<Creator> _popular = const [];
  bool _isLoadingCreators = false;
  String? _creatorsError;
  int _creatorLoadToken = 0;
  bool _disposed = false;

  KemonoServer get selectedServer => _servers.selectedServer;

  SearchMode get mode => _mode;

  List<Creator> get suggestions => _suggestions;

  List<Creator> get popularCreators => _popular;

  bool get isLoadingCreators => _isLoadingCreators;

  /// Whether at least one creator list has been received for the current
  /// server.
  bool get hasCreators => _creators.isNotEmpty;

  String? get creatorsError => _creatorsError;

  String? get queryError => _queryError;

  void selectServer(KemonoServer server) {
    _servers.select(server);
  }

  /// Switches to the newly selected or edited server, resetting the query.
  void _handleServersChanged() {
    final server = _servers.selectedServer;
    if (server.host == _selectedHost) return;
    _selectedHost = server.host;
    _queryError = null;
    _query = '';
    _suggestions = const [];
    _repository.warmUpCreators(server);
    _loadCreators();
    _notify();
  }

  void setMode(SearchMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _queryError = null;
    _notify();
  }

  void updateQuery(String value) {
    if (value == _query) return;
    _query = value;
    _queryError = null;
    _recomputeSuggestions();
    _notify();
  }

  /// Validates the entered post search query and produces the source for the
  /// slideshow. Returns null and sets [queryError] when the query is too short.
  SlideshowSource? buildPostSearchSource(String value) {
    final trimmed = value.trim();
    if (trimmed.length < minPostQueryLength) {
      _queryError =
          'Enter at least $minPostQueryLength characters to search posts.';
      _notify();
      return null;
    }
    _queryError = null;
    _notify();
    return PostSearchSource(trimmed);
  }

  /// Resolves the entered text to a creator, preferring an exact ID or name
  /// match and falling back to a single remaining suggestion.
  Creator? resolveCreator(String value) {
    final trimmed = value.trim();
    if (_isLoadingCreators && _creators.isEmpty) {
      _queryError = 'The author list is still loading.';
      _notify();
      return null;
    }
    if (trimmed.isEmpty) {
      _queryError = 'Select an author from the list.';
      _notify();
      return null;
    }

    Creator? exact;
    for (final creator in _creators) {
      if (creator.id == trimmed ||
          creator.displayName.toLowerCase() == trimmed.toLowerCase()) {
        exact = creator;
        break;
      }
    }
    if (exact != null) return exact;

    final matches = _suggestionsFor(trimmed);
    if (matches.length == 1) return matches.first;

    _queryError = matches.isEmpty
        ? 'No author matches "$trimmed".'
        : 'Select an author from the list.';
    _notify();
    return null;
  }

  /// Retries a failed creator directory request.
  void retryCreators() {
    _creatorsByServer.remove(_servers.selectedServer);
    _creatorsError = null;
    _loadCreators();
  }

  Future<void> _loadCreators() async {
    final server = _servers.selectedServer;

    final cached = _creatorsByServer[server];
    if (cached != null) {
      _creators = cached;
      _popular = _popularByServer[server] ?? const [];
      _suggestions = _query.trim().isEmpty ? _popular : _suggestionsFor(_query);
      _isLoadingCreators = false;
      _creatorsError = null;
      _notify();
      return;
    }

    final token = ++_creatorLoadToken;
    _creators = const [];
    _popular = const [];
    _suggestions = const [];
    _creatorsError = null;
    _isLoadingCreators = true;
    _notify();

    try {
      final list = await _repository.creators(server);
      if (_disposed || token != _creatorLoadToken) return;

      _creatorsByServer[server] = list;
      _creators = list;
      _popular = _computePopular(list);
      _popularByServer[server] = _popular;
    } catch (error) {
      if (_disposed || token != _creatorLoadToken) return;
      _creatorsError = error.toString();
    } finally {
      if (!_disposed && token == _creatorLoadToken) {
        _isLoadingCreators = false;
        _recomputeSuggestions();
        _notify();
      }
    }
  }

  List<Creator> _suggestionsFor(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return _popular;

    final matches = <Creator>[];
    for (final creator in _creators) {
      if (creator.displayName.toLowerCase().contains(query) ||
          creator.id == value.trim()) {
        matches.add(creator);
        if (matches.length >= maxSuggestions) break;
      }
    }
    return matches;
  }

  void _recomputeSuggestions() {
    _suggestions = _suggestionsFor(_query);
  }

  static List<Creator> _computePopular(List<Creator> creators) {
    final sorted = [...creators]
      ..sort((a, b) => b.favorited.compareTo(a.favorited));
    return sorted.take(12).toList();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _servers.removeListener(_handleServersChanged);
    if (_ownsServers) _servers.dispose();
    super.dispose();
  }
}
