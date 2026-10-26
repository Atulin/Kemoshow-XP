import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../../domain/models/media_item.dart';
import 'image_slide.dart';

/// Renders a single slideshow entry.
///
/// Videos share a single [VideoController] owned by the slideshow, so only the
/// active page is allowed to render the video output. Neighbouring pages show a
/// lightweight placeholder instead.
class MediaSlide extends StatelessWidget {
  const MediaSlide({
    super.key,
    required this.item,
    required this.isActive,
    required this.videoController,
    required this.onToggleHeader,
    required this.onZoomChanged,
  });

  final MediaItem item;
  final bool isActive;
  final VideoController videoController;

  /// Called when the media is tapped, e.g. to hide the slideshow header.
  final VoidCallback onToggleHeader;

  /// Called when the image starts or stops being zoomed in.
  final ValueChanged<bool> onZoomChanged;

  @override
  Widget build(BuildContext context) {
    if (!item.isVideo) {
      return ImageSlide(
        url: item.url,
        name: item.name,
        isActive: isActive,
        onTap: onToggleHeader,
        onZoomChanged: isActive ? onZoomChanged : null,
      );
    }

    if (!isActive) {
      return _VideoPlaceholder(item: item);
    }

    return Video(
      controller: videoController,
      fit: BoxFit.contain,
      fill: Colors.black,
      controls: NoVideoControls,
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 64,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
