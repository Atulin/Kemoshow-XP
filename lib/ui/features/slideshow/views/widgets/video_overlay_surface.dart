import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Full-screen gesture surface of the video controls overlay.
///
/// The slideshow's [PageView] sits *behind* this surface. An opaque hit test
/// (`MouseRegion`'s default) takes the pages out of the hit-test path, so
/// horizontal swipes stop working as soon as a video is shown. The surface
/// therefore stays translucent: the pointer still reaches the pages, while the
/// tap detector only competes for taps in the gesture arena.
///
/// [child] keeps normal hit testing, so controls inside it stay interactive.
class VideoOverlaySurface extends StatelessWidget {
  const VideoOverlaySurface({
    super.key,
    required this.onTap,
    required this.onHover,
    required this.child,
  });

  /// Called when the video is tapped, e.g. to toggle the controls.
  final VoidCallback onTap;

  /// Called when the pointer hovers over the video, e.g. to reveal the
  /// controls again.
  final void Function(PointerHoverEvent event) onHover;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      onHover: onHover,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
