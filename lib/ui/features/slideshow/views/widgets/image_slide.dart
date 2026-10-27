import 'package:flutter/material.dart';

/// Image provider for a slideshow image.
///
/// Images are decoded at roughly their on-screen size instead of their full
/// resolution, which keeps memory usage low enough to preload several of them.
/// The preloader uses the same provider so the decoded image is shared through
/// Flutter's image cache.
ImageProvider mediaImageProvider(BuildContext context, String url) {
  final media = MediaQuery.maybeOf(context);
  var width = media == null
      ? 1024
      : (media.size.width * media.devicePixelRatio).round();
  if (width <= 0) width = 1024;
  return ResizeImage(NetworkImage(url), width: width);
}

/// A single image of the slideshow, with loading, error and zoom support.
///
/// Pinching zooms the image, a double tap switches between the regular and the
/// maximum zoom level, and a zoomed image can be panned. The slideshow disables
/// page swiping while the image is zoomed, so panning takes precedence.
class ImageSlide extends StatefulWidget {
  const ImageSlide({
    super.key,
    required this.url,
    required this.name,
    this.previewUrl,
    this.onTap,
    this.isActive = true,
    this.onZoomChanged,
  });

  final String url;
  final String name;

  /// Downscaled preview to use when [url] cannot be loaded.
  ///
  /// Posts that are not archived completely yet only serve a preview.
  final String? previewUrl;

  /// Called when the image is tapped, e.g. to toggle the slideshow header.
  final VoidCallback? onTap;

  /// Whether this image is the visible page of the slideshow. Zoom is reset
  /// when the page becomes inactive.
  final bool isActive;

  /// Called when the image starts or stops being zoomed in.
  final ValueChanged<bool>? onZoomChanged;

  @override
  State<ImageSlide> createState() => _ImageSlideState();
}

class _ImageSlideState extends State<ImageSlide>
    with SingleTickerProviderStateMixin {
  /// Scale reached by a double tap and the upper limit for pinching.
  static const double _maxScale = 4;

  /// Scales above this value count as zoomed in.
  static const double _zoomedThreshold = 1.01;

  final TransformationController _transformationController =
      TransformationController();

  late final AnimationController _zoomController;
  Animation<Matrix4>? _zoomAnimation;
  Offset? _doubleTapPosition;
  bool _zoomed = false;
  bool _usingPreview = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _zoomController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          final animation = _zoomAnimation;
          if (animation != null) {
            _transformationController.value = animation.value;
          }
        });
    _transformationController.addListener(_handleTransformChanged);
  }

  @override
  void didUpdateWidget(ImageSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url ||
        widget.previewUrl != oldWidget.previewUrl) {
      _usingPreview = false;
      _attempt++;
      _resetZoom(notify: false);
    } else if (oldWidget.isActive && !widget.isActive) {
      _resetZoom(notify: false);
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  double get _scale => _transformationController.value.getMaxScaleOnAxis();

  void _handleTransformChanged() {
    final zoomed = _scale > _zoomedThreshold;
    if (zoomed == _zoomed) return;
    setState(() => _zoomed = zoomed);
    widget.onZoomChanged?.call(zoomed);
  }

  void _resetZoom({bool notify = true}) {
    _zoomController.stop();
    _zoomAnimation = null;
    final wasZoomed = _zoomed;
    _zoomed = false;
    _transformationController.value = Matrix4.identity();
    if (notify && wasZoomed) widget.onZoomChanged?.call(false);
  }

  /// Matrix that scales around [focalPoint], keeping it in place.
  static Matrix4 _zoomMatrix(Offset focalPoint, double scale) {
    return Matrix4.identity()
      ..translateByDouble(
        focalPoint.dx * (1 - scale),
        focalPoint.dy * (1 - scale),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
        );
    _zoomController.forward(from: 0);
  }

  void _toggleZoom() {
    if (_scale > _zoomedThreshold) {
      _animateTo(Matrix4.identity());
      return;
    }

    final size = context.size;
    final focalPoint =
        _doubleTapPosition ??
        (size == null ? Offset.zero : size.center(Offset.zero));
    _animateTo(_zoomMatrix(focalPoint, _maxScale));
  }

  void _retry() {
    final previewUrl = widget.previewUrl;
    PaintingBinding.instance.imageCache.evict(
      mediaImageProvider(context, widget.url),
    );
    if (previewUrl != null) {
      PaintingBinding.instance.imageCache.evict(
        mediaImageProvider(context, previewUrl),
      );
    }
    _resetZoom(notify: false);
    setState(() {
      _usingPreview = false;
      _attempt++;
    });
  }

  /// Switches to the preview after the full file failed to load.
  ///
  /// The switch is deferred to after the frame because the error is reported
  /// while the widget is being built.
  void _usePreview() {
    if (_usingPreview) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _usingPreview) return;
      setState(() {
        _usingPreview = true;
        _attempt++;
      });
    });
  }

  String get _effectiveUrl => _usingPreview && widget.previewUrl != null
      ? widget.previewUrl!
      : widget.url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = mediaImageProvider(context, _effectiveUrl);

    return Semantics(
      image: true,
      label: widget.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTapDown: (details) {
          _doubleTapPosition = details.localPosition;
        },
        onDoubleTap: _toggleZoom,
        child: ClipRect(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1,
            maxScale: _maxScale,
            // While not zoomed in, one-finger drags belong to the slideshow.
            // Pinching stays available because it is a separate gesture.
            panEnabled: _zoomed,
            scaleEnabled: true,
            onInteractionStart: (_) {
              _zoomController.stop();
              _zoomAnimation = null;
            },
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Image(
                  image: provider,
                  key: ValueKey(_attempt),
                  fit: BoxFit.contain,
                  gaplessPlayback: false,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    final total = progress.expectedTotalBytes;
                    final value = total == null || total == 0
                        ? null
                        : progress.cumulativeBytesLoaded / total;
                    return Center(
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 3,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    if (!_usingPreview && widget.previewUrl != null) {
                      _usePreview();
                      return const Center(
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 12),
                          const Text('Could not load this image.'),
                          const SizedBox(height: 4),
                          Text(
                            widget.name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
