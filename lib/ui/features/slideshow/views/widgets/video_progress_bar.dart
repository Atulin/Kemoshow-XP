import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Thin progress bar pinned to the top of the screen for the active video.
///
/// It stays visible even while the regular controls are hidden.
class VideoProgressBar extends StatelessWidget {
  const VideoProgressBar({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (context, durationSnapshot) {
            final positionMs =
                (positionSnapshot.data ?? Duration.zero).inMilliseconds;
            final durationMs =
                (durationSnapshot.data ?? Duration.zero).inMilliseconds;
            final value = durationMs <= 0
                ? 0.0
                : (positionMs / durationMs).clamp(0.0, 1.0);

            return SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                color: theme.colorScheme.primary,
              ),
            );
          },
        );
      },
    );
  }
}
