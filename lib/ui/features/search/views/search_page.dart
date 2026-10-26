import 'package:flutter/material.dart';

import '../../../../core/kemono_server.dart';
import '../../../../data/models/creator.dart';
import '../../../../data/repositories/kemono_repository.dart';
import '../../../../domain/models/favourite.dart';
import '../../../../domain/models/slideshow_source.dart';
import '../../favourites/view_models/favourites_controller.dart';
import '../../favourites/views/favourites_sheet.dart';
import '../../settings/view_models/settings_controller.dart';
import '../../settings/views/settings_dialog.dart';
import '../../slideshow/views/slideshow_page.dart';
import '../view_models/search_view_model.dart';

/// Landing screen: pick a server, switch between post and author search, then
/// open the slideshow.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.repository,
    required this.settingsController,
    required this.favouritesController,
  });

  final KemonoRepository repository;
  final SettingsController settingsController;
  final FavouritesController favouritesController;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final SearchViewModel _viewModel;
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _viewModel = SearchViewModel(widget.repository);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _openSlideshow(SlideshowSource source) {
    _queryFocus.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SlideshowPage(
          repository: widget.repository,
          source: source,
          server: _viewModel.selectedServer,
          settings: widget.settingsController.settings,
          favouritesController: widget.favouritesController,
        ),
      ),
    );
  }

  /// Opens a saved favourite, switching servers first when it belongs to
  /// another one.
  void _openFavourite(Favourite favourite) {
    if (favourite.server != _viewModel.selectedServer) {
      _queryController.clear();
      _viewModel.selectServer(favourite.server);
    }

    switch (favourite) {
      case PostSearchFavourite(:final term):
        _viewModel.setMode(SearchMode.posts);
        _queryController.value = TextEditingValue(
          text: term,
          selection: TextSelection.collapsed(offset: term.length),
        );
        _viewModel.updateQuery(term);
      case AuthorFavourite():
        _viewModel.setMode(SearchMode.creators);
        _queryController.clear();
        _viewModel.updateQuery('');
    }

    _openSlideshow(favourite.toSource());
  }

  Future<void> _showFavourites() async {
    _queryFocus.unfocus();
    final selected = await showModalBottomSheet<Favourite>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FavouritesSheet(controller: widget.favouritesController),
    );
    if (selected == null || !mounted) return;
    _openFavourite(selected);
  }

  void _submit() {
    switch (_viewModel.mode) {
      case SearchMode.posts:
        final source = _viewModel.buildPostSearchSource(_queryController.text);
        if (source != null) _openSlideshow(source);
      case SearchMode.creators:
        final creator = _viewModel.resolveCreator(_queryController.text);
        if (creator != null) _openSlideshow(CreatorSource(creator));
    }
  }

  void _selectServer(KemonoServer? server) {
    if (server == null || server == _viewModel.selectedServer) return;
    _queryController.clear();
    _viewModel.selectServer(server);
  }

  void _setMode(SearchMode mode) {
    _viewModel.setMode(mode);
    _queryFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _viewModel,
            widget.favouritesController,
          ]),
          builder: (context, _) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        selectedServer: _viewModel.selectedServer,
                        onServerChanged: _selectServer,
                        hasFavourites:
                            widget.favouritesController.favourites.isNotEmpty,
                        onOpenFavourites: () => _showFavourites(),
                        onOpenSettings: () => showSettingsDialog(
                          context,
                          widget.settingsController,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildModeSwitch(),
                      const SizedBox(height: 16),
                      _buildSearchField(),
                      if (_viewModel.queryError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _viewModel.queryError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModeSwitch() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<SearchMode>(
        segments: const [
          ButtonSegment(
            value: SearchMode.posts,
            icon: Icon(Icons.article_outlined),
            label: Text('Post search'),
          ),
          ButtonSegment(
            value: SearchMode.creators,
            icon: Icon(Icons.person_outline),
            label: Text('Author search'),
          ),
        ],
        selected: {_viewModel.mode},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => _setMode(selection.first),
      ),
    );
  }

  Widget _buildSearchField() {
    final isAuthors = _viewModel.mode == SearchMode.creators;
    return TextField(
      controller: _queryController,
      focusNode: _queryFocus,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: _viewModel.updateQuery,
      onSubmitted: (_) => _submit(),
      onTapOutside: (_) => _queryFocus.unfocus(),
      decoration: InputDecoration(
        hintText: isAuthors ? 'Search authors…' : 'Search posts…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _buildFieldActions(isAuthors),
      ),
    );
  }

  Widget _buildFieldActions(bool isAuthors) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _queryController,
        widget.favouritesController,
      ]),
      builder: (context, _) {
        final text = _queryController.text;
        final trimmed = text.trim();

        // A post search can only be saved once it is long enough to run.
        final favourite =
            !isAuthors && trimmed.length >= SearchViewModel.minPostQueryLength
            ? PostSearchFavourite(_viewModel.selectedServer, trimmed)
            : null;
        final isFavourite =
            favourite != null &&
            widget.favouritesController.contains(favourite);

        if (favourite == null && text.isEmpty) return const SizedBox.shrink();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (favourite != null)
              IconButton(
                tooltip: isFavourite
                    ? 'Remove post search from favourites'
                    : 'Favourite this post search',
                onPressed: () => widget.favouritesController.toggle(favourite),
                icon: Icon(
                  isFavourite ? Icons.star : Icons.star_border,
                  color: isFavourite
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            if (text.isNotEmpty)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _queryController.clear();
                  _viewModel.updateQuery('');
                  _queryFocus.requestFocus();
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    return switch (_viewModel.mode) {
      SearchMode.posts => _buildPostHint(),
      SearchMode.creators => _buildAuthorResults(),
    };
  }

  Widget _buildPostHint() {
    final theme = Theme.of(context);
    final server = _viewModel.selectedServer;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.slideshow_outlined,
              size: 56,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'Search all media posted to ${server.host}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter at least ${SearchViewModel.minPostQueryLength} characters, '
              'then press Enter to open the slideshow.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorResults() {
    final theme = Theme.of(context);

    if (_viewModel.isLoadingCreators && !_viewModel.hasCreators) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading authors…'),
          ],
        ),
      );
    }

    final error = _viewModel.creatorsError;
    if (error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Could not load the author list.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _viewModel.retryCreators,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final suggestions = _viewModel.suggestions;
    if (suggestions.isEmpty) {
      return Center(
        child: Text(
          _queryController.text.trim().isEmpty
              ? 'Start typing to find an author.'
              : 'No authors match your search.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final title = _queryController.text.trim().isEmpty
        ? 'Popular authors'
        : 'Authors';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (_viewModel.isLoadingCreators)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '${_viewModel.suggestions.length} shown',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final creator = suggestions[index];
              final favourite = AuthorFavourite(
                server: _viewModel.selectedServer,
                id: creator.id,
                service: creator.service,
                name: creator.name,
              );
              return _CreatorTile(
                creator: creator,
                isFavourite: widget.favouritesController.contains(favourite),
                onToggleFavourite: () =>
                    widget.favouritesController.toggle(favourite),
                onTap: () => _openSlideshow(CreatorSource(creator)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.selectedServer,
    required this.onServerChanged,
    required this.hasFavourites,
    required this.onOpenFavourites,
    required this.onOpenSettings,
  });

  final KemonoServer selectedServer;
  final ValueChanged<KemonoServer?> onServerChanged;
  final bool hasFavourites;
  final VoidCallback onOpenFavourites;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // On phones the logo would squeeze the title and the three actions; the
        // title alone is enough branding there.
        final compact = constraints.maxWidth < 480;
        return Row(
          children: [
            if (!compact) ...[
              Icon(Icons.slideshow, color: theme.colorScheme.primary, size: 30),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                'KemoShow',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<KemonoServer>(
                  value: selectedServer,
                  borderRadius: BorderRadius.circular(12),
                  icon: Icon(Icons.expand_more, size: compact ? 18 : 20),
                  style: compact
                      ? theme.textTheme.bodySmall
                      : theme.textTheme.bodyMedium,
                  onChanged: onServerChanged,
                  items: [
                    for (final server in KemonoServer.values)
                      DropdownMenuItem(
                        value: server,
                        child: Text(server.label),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Favourites',
              onPressed: onOpenFavourites,
              icon: Icon(hasFavourites ? Icons.star : Icons.star_border),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        );
      },
    );
  }
}

class _CreatorTile extends StatelessWidget {
  const _CreatorTile({
    required this.creator,
    required this.isFavourite,
    required this.onToggleFavourite,
    required this.onTap,
  });

  final Creator creator;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = creator.displayName.isEmpty
        ? '?'
        : creator.displayName.substring(0, 1).toUpperCase();

    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text(initial),
        ),
        title: Text(
          creator.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${creator.service} · ${creator.id}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (creator.favorited > 0) ...[
              Icon(Icons.favorite, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Text('${creator.favorited}', style: theme.textTheme.labelSmall),
              const SizedBox(width: 4),
            ],
            IconButton(
              tooltip: isFavourite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              onPressed: onToggleFavourite,
              icon: Icon(
                isFavourite ? Icons.star : Icons.star_border,
                size: 20,
              ),
              color: isFavourite
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
