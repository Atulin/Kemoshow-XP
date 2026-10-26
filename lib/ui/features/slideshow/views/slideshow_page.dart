import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/kemono_server.dart';
import '../../../../data/repositories/kemono_repository.dart';
import '../../../../data/services/platform_media_saver.dart';
import '../../../../domain/models/app_settings.dart';
import '../../../../domain/models/media_item.dart';
import '../../../../domain/models/slideshow_source.dart';
import '../../../../domain/services/media_saver.dart';
import '../../../core/platform_support.dart';
import '../view_models/slideshow_view_model.dart';
import 'widgets/image_slide.dart';
import 'widgets/media_slide.dart';
import 'widgets/shortcuts_help_dialog.dart';
import 'widgets/video_controls_overlay.dart';
import 'widgets/video_progress_bar.dart';

/// Fullscreen slideshow over the flattened media of a post search or creator.
class SlideshowPage extends StatefulWidget {
  const SlideshowPage({
    super.key,
    required this.repository,
    required this.source,
    required this.server,
    required this.settings,
    this.mediaSaver,
  });

  final KemonoRepository repository;
  final SlideshowSource source;
  final KemonoServer server;
  final AppSettings settings;

  /// Overrides how media is saved. Defaults to the platform behaviour:
  /// gallery on mobile, a chosen folder on desktop.
  final MediaSaver? mediaSaver;

  @override
  State<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends State<SlideshowPage> {
  late final SlideshowViewModel _viewModel;
  late final Player _player;
  late final VideoController _videoController;
  late final PageController _pageController;
  late final StreamSubscription<String> _playerErrorSubscription;
  late final MediaSaver _mediaSaver;

  String? _currentVideoUrl;
  String? _lastPlayerError;
  int? _pendingIndex;
  final Set<ImageProvider> _preloadedImages = {};
  bool _preloadScheduled = false;
  bool _isSaving = false;
  bool _isChoosingSaveTarget = false;
  final ValueNotifier<MediaSaveProgress?> _saveProgress = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _viewModel = SlideshowViewModel(
      widget.repository,
      source: widget.source,
      server: widget.server,
      includeLinkedMedia: widget.settings.scanPostContent,
    );
    _player = Player(configuration: PlayerConfiguration(title: 'KemoShow'));
    _videoController = VideoController(_player);
    _pageController = PageController();
    _mediaSaver = widget.mediaSaver ?? PlatformMediaSaver();
    _viewModel.addListener(_handleViewModelChanged);
    _playerErrorSubscription = _player.stream.error.listen(_onPlayerError);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    unawaited(_viewModel.loadInitial());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _viewModel.removeListener(_handleViewModelChanged);
    _viewModel.dispose();
    _playerErrorSubscription.cancel();
    unawaited(_player.dispose());
    _pageController.dispose();
    _saveProgress.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Video synchronisation
  // ---------------------------------------------------------------------------

  void _handleViewModelChanged() {
    if (!mounted) return;

    final item = _viewModel.current;
    final videoUrl = item?.isVideo == true ? item!.url : null;
    if (videoUrl != _currentVideoUrl) {
      _currentVideoUrl = videoUrl;
      if (videoUrl == null) {
        unawaited(_player.stop());
      } else {
        unawaited(_player.open(Media(videoUrl), play: true));
      }
    }

    final pending = _pendingIndex;
    if (pending != null) {
      if (_viewModel.items.length > pending) {
        _pendingIndex = null;
        _goTo(pending);
      } else if (!_viewModel.hasMore || _viewModel.error != null) {
        _pendingIndex = null;
      }
    }

    _schedulePreload();
  }

  // ---------------------------------------------------------------------------
  // Preloading
  // ---------------------------------------------------------------------------

  /// Schedules preloading of the next images after the current frame.
  void _schedulePreload() {
    if (_preloadScheduled || widget.settings.preloadCount <= 0) return;
    _preloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadScheduled = false;
      if (mounted) _preloadAhead();
    });
  }

  /// Warms the image cache for the next few slides.
  ///
  /// Images are decoded at display size (see [mediaImageProvider]), so keeping
  /// a handful of them around stays within Flutter's default image cache
  /// budget. Videos cannot be preloaded this way and are opened when reached.
  void _preloadAhead() {
    final items = _viewModel.items;
    final current = _viewModel.currentIndex;
    final count = widget.settings.preloadCount;
    final end = current + 1 + count <= items.length
        ? current + 1 + count
        : items.length;

    for (var index = current + 1; index < end; index++) {
      final item = items[index];
      if (item.isVideo) continue;

      final provider = mediaImageProvider(context, item.url);
      if (!_preloadedImages.add(provider)) continue;

      unawaited(
        precacheImage(
          provider,
          context,
          onError: (error, stackTrace) => _preloadedImages.remove(provider),
        ),
      );
    }
  }

  void _onPlayerError(String message) {
    if (!mounted || message.isEmpty || message == _lastPlayerError) return;
    _lastPlayerError = message;
    _showMessage('Playback error: $message');
  }

  // ---------------------------------------------------------------------------
  // Saving media
  // ---------------------------------------------------------------------------

  /// Downloads the current media to the gallery or a folder.
  ///
  /// Mobile users choose the destination in a sheet; on desktop the folder
  /// picker opens directly, since there is no gallery target.
  Future<void> _saveCurrent() async {
    if (_isSaving || _isChoosingSaveTarget) return;
    final item = _viewModel.current;
    if (item == null) return;

    MediaSaveTarget? target = MediaSaveTarget.folder;
    if (_mediaSaver.supportsGallery) {
      _isChoosingSaveTarget = true;
      try {
        target = await _chooseSaveTarget(item);
      } finally {
        _isChoosingSaveTarget = false;
      }
    }
    if (target == null || !mounted) return;

    setState(() => _isSaving = true);
    _saveProgress.value = const MediaSaveProgress(receivedBytes: 0);
    try {
      final result = await _mediaSaver.save(
        item,
        target: target,
        onProgress: (progress) {
          if (mounted) _saveProgress.value = progress;
        },
      );
      if (!mounted || result == null) return;
      _showMessage('Saved ${item.name} to ${result.destination}.');
    } on MediaSaveException catch (error) {
      if (mounted) _showMessage('Could not save media: ${error.message}');
    } catch (error) {
      if (mounted) _showMessage('Could not save media: $error');
    } finally {
      if (mounted) {
        _saveProgress.value = null;
        setState(() => _isSaving = false);
      }
    }
  }

  /// Asks where a mobile download should go. Returns null when dismissed.
  Future<MediaSaveTarget?> _chooseSaveTarget(MediaItem item) {
    return showModalBottomSheet<MediaSaveTarget>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Save media', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Save to gallery'),
                subtitle: const Text('Add it to your photos'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(MediaSaveTarget.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Save to a folder'),
                subtitle: const Text('Pick a destination'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(MediaSaveTarget.folder),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _goTo(int index) {
    final items = _viewModel.items;
    if (items.isEmpty) return;

    final target = index.clamp(0, items.length - 1);
    if (target == _viewModel.currentIndex) {
      if (target == items.length - 1 && _viewModel.hasMore) {
        unawaited(_viewModel.loadMore());
      }
      return;
    }

    if (!_pageController.hasClients) return;
    unawaited(
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _previous() => _goTo(_viewModel.currentIndex - 1);

  void _next() {
    final target = _viewModel.currentIndex + 1;
    if (target >= _viewModel.items.length) {
      if (_viewModel.hasMore) {
        _pendingIndex = target;
        unawaited(_viewModel.loadMore());
      }
      return;
    }
    _goTo(target);
  }

  void _seekBy(Duration delta) {
    if (_viewModel.current?.isVideo != true) return;

    final duration = _player.state.duration;
    var target = _player.state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    unawaited(_player.seek(target));
  }

  void _togglePlayback() {
    if (_viewModel.current?.isVideo != true) return;
    unawaited(_player.playOrPause());
  }

  Future<void> _toggleMute() async {
    if (_viewModel.current?.isVideo != true) return;
    await _player.setVolume(_player.state.volume > 0 ? 0 : 100);
  }

  // ---------------------------------------------------------------------------
  // Keyboard handling
  // ---------------------------------------------------------------------------

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted || event is KeyUpEvent) return false;

    // Don't steal keys while a dialog (help) or another route is on top.
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    final hardware = HardwareKeyboard.instance;
    final shift = hardware.isShiftPressed;
    final key = event.logicalKey;
    final isVideo = _viewModel.current?.isVideo ?? false;

    if (key == LogicalKeyboardKey.escape) {
      unawaited(Navigator.of(context).maybePop());
      return true;
    }
    if (key == LogicalKeyboardKey.keyS &&
        (hardware.isControlPressed || hardware.isMetaPressed)) {
      unawaited(_saveCurrent());
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      if (shift && isVideo) {
        _seekBy(const Duration(seconds: -30));
      } else {
        _previous();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      if (shift && isVideo) {
        _seekBy(const Duration(seconds: 30));
      } else {
        _next();
      }
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      if (isVideo) _seekBy(const Duration(seconds: 5));
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      if (isVideo) _seekBy(const Duration(seconds: -5));
      return true;
    }
    if (key == LogicalKeyboardKey.keyJ) {
      if (isVideo) _seekBy(const Duration(seconds: -10));
      return true;
    }
    if (key == LogicalKeyboardKey.keyL) {
      if (isVideo) _seekBy(const Duration(seconds: 10));
      return true;
    }
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      if (isVideo) _togglePlayback();
      return true;
    }
    if (key == LogicalKeyboardKey.keyM) {
      if (isVideo) unawaited(_toggleMute());
      return true;
    }
    if (key == LogicalKeyboardKey.home) {
      _goTo(0);
      return true;
    }
    if (key == LogicalKeyboardKey.end) {
      _goTo(_viewModel.items.length - 1);
      return true;
    }
    if (key == LogicalKeyboardKey.keyH || event.character == '?') {
      unawaited(showShortcutsHelp(context));
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final items = _viewModel.items;
          final current = _viewModel.current;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (items.isEmpty)
                _buildEmptyState(context)
              else
                _buildPages(items),
              if (current != null && current.isVideo)
                Positioned.fill(
                  child: VideoControlsOverlay(
                    key: ValueKey(_currentVideoUrl),
                    player: _player,
                  ),
                ),
              if (current != null) _buildHeader(context, current, items.length),
              if (current != null && current.isVideo)
                Positioned(
                  // Stay visible on edge-to-edge devices with a status bar or
                  // notch, where the very top of the screen is covered.
                  top: MediaQuery.paddingOf(context).top,
                  left: 0,
                  right: 0,
                  child: VideoProgressBar(player: _player),
                ),
              if (_viewModel.isLoading && items.isNotEmpty)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_viewModel.error != null && items.isNotEmpty)
                _buildLoadMoreError(
                  context,
                  isVideo: current?.isVideo ?? false,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPages(List<MediaItem> items) {
    return ScrollConfiguration(
      // Allow dragging the slideshow with a mouse on desktop.
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: _viewModel.onPageChanged,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return MediaSlide(
            key: ValueKey(item.url),
            item: item,
            isActive: index == _viewModel.currentIndex,
            videoController: _videoController,
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MediaItem item, int loadedCount) {
    final theme = Theme.of(context);
    final post = item.post;
    final rawTitle = post.title?.trim() ?? '';
    final title = rawTitle.isEmpty ? item.name : rawTitle;

    final subtitleParts = <String>[
      if (post.service != null && post.service!.isNotEmpty) post.service!,
      if (post.user != null && post.user!.isNotEmpty) post.user!,
    ];
    final subtitle = subtitleParts.join(' · ');

    final position = _viewModel.currentIndex + 1;
    final counter = _viewModel.hasMore
        ? '$position / $loadedCount+'
        : '$position / $loadedCount';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Stack(
        children: [
          IgnorePointer(
            child: Container(
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back (Esc)',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: IgnorePointer(
                      // The title is not interactive; letting it absorb
                      // pointers would create a dead zone for page swipes.
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        counter,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildSaveButton(),
                  if (isDesktopPlatform) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Keyboard shortcuts (?)',
                      onPressed: () => unawaited(showShortcutsHelp(context)),
                      icon: const Icon(
                        Icons.keyboard_outlined,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final tooltip = _mediaSaver.supportsGallery
        ? 'Save media'
        : 'Save to a folder (Ctrl+S)';
    return ValueListenableBuilder<MediaSaveProgress?>(
      valueListenable: _saveProgress,
      builder: (context, progress, _) {
        final saving = progress != null;
        return IconButton(
          tooltip: saving ? 'Saving…' : tooltip,
          onPressed: saving ? null : () => unawaited(_saveCurrent()),
          icon: saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    value: progress.fraction,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.download_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final error = _viewModel.error;

    return SafeArea(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: 'Back (Esc)',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_viewModel.isInitialLoading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      'Loading media…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ] else if (error != null) ...[
                    Icon(
                      Icons.cloud_off,
                      size: 52,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load media.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: _viewModel.retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ] else ...[
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 52,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No media found for "${widget.source.title}".',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try a different search term or author.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Back to search'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreError(BuildContext context, {required bool isVideo}) {
    final theme = Theme.of(context);
    return Positioned(
      left: 16,
      right: 16,
      bottom: isVideo ? 96 : 24,
      child: Center(
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 18),
                const SizedBox(width: 8),
                const Flexible(child: Text('Could not load more media.')),
                TextButton(
                  onPressed: _viewModel.retry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
