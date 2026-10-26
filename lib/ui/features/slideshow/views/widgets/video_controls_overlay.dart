import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../core/duration_label.dart';
import '../../../../core/platform_support.dart';
import 'shortcuts_help_dialog.dart';
import 'video_overlay_surface.dart';

/// Custom video controls drawn over the shared video output.
///
/// The slideshow has its own keyboard navigation, so media_kit's default
/// controls are disabled and replaced with this overlay. Tapping toggles the
/// controls; they hide themselves while the video is playing.
class VideoControlsOverlay extends StatefulWidget {
  const VideoControlsOverlay({super.key, required this.player});

  final Player player;

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  static const Duration _autoHideDelay = Duration(seconds: 3);

  bool _visible = true;
  bool _buffering = false;
  bool _pointerOverControls = false;
  String? _error;
  Timer? _hideTimer;
  late final StreamSubscription<bool> _playingSubscription;
  late final StreamSubscription<bool> _bufferingSubscription;
  late final StreamSubscription<String> _errorSubscription;

  Player get _player => widget.player;

  @override
  void initState() {
    super.initState();
    _playingSubscription = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (playing) {
        _restartHideTimer();
      } else {
        _hideTimer?.cancel();
        setState(() => _visible = true);
      }
    });
    _bufferingSubscription = _player.stream.buffering.listen((buffering) {
      if (!mounted || buffering == _buffering) return;
      setState(() => _buffering = buffering);
    });
    _errorSubscription = _player.stream.error.listen((message) {
      if (!mounted || message.isEmpty) return;
      _hideTimer?.cancel();
      setState(() {
        _error = message;
        _visible = true;
      });
    });
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playingSubscription.cancel();
    _bufferingSubscription.cancel();
    _errorSubscription.cancel();
    super.dispose();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    if (!_player.state.playing || _pointerOverControls) return;
    _hideTimer = Timer(_autoHideDelay, () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  void _show() {
    if (!_visible) setState(() => _visible = true);
    _restartHideTimer();
  }

  void _toggle() {
    if (_visible) {
      _hideTimer?.cancel();
      setState(() => _visible = false);
    } else {
      _show();
    }
  }

  void _togglePlayback() {
    _error = null;
    unawaited(_player.playOrPause());
    _show();
  }

  Future<void> _toggleMute() async {
    if (_player.state.volume > 0) {
      await _player.setVolume(0);
    } else {
      await _player.setVolume(100);
    }
    _show();
  }

  @override
  Widget build(BuildContext context) {
    return VideoOverlaySurface(
      onTap: _toggle,
      onHover: (_) {
        if (!_visible) _show();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_error != null)
            Center(
              child: _VideoError(
                message: _error!,
                onDismiss: () {
                  setState(() => _error = null);
                },
              ),
            )
          else if (_buffering)
            const Center(
              child: SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          else
            Center(
              child: StreamBuilder<bool>(
                stream: _player.stream.playing,
                initialData: _player.state.playing,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  if (playing) return const SizedBox.shrink();
                  return _CenterPlayButton(onPressed: _togglePlayback);
                },
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_visible,
                child: _buildControlBar(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) {
        _pointerOverControls = true;
        _hideTimer?.cancel();
        _show();
      },
      onExit: (_) {
        _pointerOverControls = false;
        _restartHideTimer();
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 24, 12, 8),
            child: Row(
              children: [
                StreamBuilder<bool>(
                  stream: _player.stream.playing,
                  initialData: _player.state.playing,
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? false;
                    return IconButton(
                      tooltip: playing ? 'Pause (Space)' : 'Play (Space)',
                      onPressed: _togglePlayback,
                      icon: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    );
                  },
                ),
                Expanded(child: _VideoScrubber(player: _player)),
                StreamBuilder<double>(
                  stream: _player.stream.volume,
                  initialData: _player.state.volume,
                  builder: (context, snapshot) {
                    final muted = (snapshot.data ?? 100) <= 0;
                    return IconButton(
                      tooltip: muted ? 'Unmute (M)' : 'Mute (M)',
                      onPressed: _toggleMute,
                      icon: Icon(
                        muted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 22,
                      ),
                    );
                  },
                ),
                if (isDesktopPlatform)
                  IconButton(
                    tooltip: 'Keyboard shortcuts (?)',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const ShortcutsHintDialog(),
                    ),
                    icon: Icon(
                      Icons.keyboard_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  const _CenterPlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        iconSize: 56,
        tooltip: 'Play (Space)',
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow, color: Colors.white),
      ),
    );
  }
}

class _VideoError extends StatelessWidget {
  const _VideoError({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 40,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not play this video.',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
            label: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

/// Position slider with time labels that survives position stream updates.
class _VideoScrubber extends StatefulWidget {
  const _VideoScrubber({required this.player});

  final Player player;

  @override
  State<_VideoScrubber> createState() => _VideoScrubberState();
}

class _VideoScrubberState extends State<_VideoScrubber> {
  double? _dragMilliseconds;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final maxMilliseconds = duration.inMilliseconds.toDouble();
            final position = positionSnapshot.data ?? Duration.zero;
            final displayedMilliseconds =
                _dragMilliseconds ?? position.inMilliseconds.toDouble();
            final value = maxMilliseconds > 0
                ? displayedMilliseconds.clamp(0.0, maxMilliseconds)
                : 0.0;

            return Row(
              children: [
                _TimeLabel(
                  Duration(milliseconds: displayedMilliseconds.round()),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      inactiveTrackColor: Colors.white24,
                      activeTrackColor: Colors.white,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white24,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      max: maxMilliseconds > 0 ? maxMilliseconds : 1,
                      onChanged: maxMilliseconds > 0
                          ? (next) => setState(() => _dragMilliseconds = next)
                          : null,
                      onChangeEnd: maxMilliseconds > 0
                          ? (next) {
                              setState(() => _dragMilliseconds = null);
                              unawaited(
                                player.seek(
                                  Duration(milliseconds: next.round()),
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ),
                _TimeLabel(duration),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel(this.duration);

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatDuration(duration),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}
