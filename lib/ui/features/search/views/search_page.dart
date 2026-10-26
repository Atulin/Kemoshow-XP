import 'package:flutter/material.dart';

import '../../../../core/kemono_server.dart';
import '../../../../data/models/creator.dart';
import '../../../../data/repositories/kemono_repository.dart';
import '../../../../domain/models/slideshow_source.dart';
import '../../slideshow/views/slideshow_page.dart';
import '../view_models/search_view_model.dart';

/// Landing screen: pick a server, switch between post and author search, then
/// open the slideshow.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.repository});

  final KemonoRepository repository;

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
        ),
      ),
    );
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
          listenable: _viewModel,
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
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _queryController,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () {
                _queryController.clear();
                _viewModel.updateQuery('');
                _queryFocus.requestFocus();
              },
            );
          },
        ),
      ),
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
              return _CreatorTile(
                creator: creator,
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
  const _Header({required this.selectedServer, required this.onServerChanged});

  final KemonoServer selectedServer;
  final ValueChanged<KemonoServer?> onServerChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.slideshow, color: theme.colorScheme.primary, size: 30),
        const SizedBox(width: 12),
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<KemonoServer>(
              value: selectedServer,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.expand_more, size: 20),
              style: theme.textTheme.bodyMedium,
              onChanged: onServerChanged,
              items: [
                for (final server in KemonoServer.values)
                  DropdownMenuItem(value: server, child: Text(server.label)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreatorTile extends StatelessWidget {
  const _CreatorTile({required this.creator, required this.onTap});

  final Creator creator;
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
        trailing: creator.favorited > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${creator.favorited}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
