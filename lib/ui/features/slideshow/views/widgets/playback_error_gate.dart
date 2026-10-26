import 'dart:async';

/// Holds player errors back for a short grace period.
///
/// Some platforms report a decoder or codec error while the player is still
/// recovering, and the video then plays normally. Waiting before showing the
/// error, and clearing it as soon as playback is observed, keeps those
/// transient failures from reaching the user.
class PlaybackErrorGate {
  PlaybackErrorGate({
    required this.onShow,
    required this.onClear,
    this.grace = const Duration(milliseconds: 500),
  });

  /// How long an error is held back before it is shown.
  final Duration grace;

  /// Called with the error message once the grace period has elapsed.
  final void Function(String message) onShow;

  /// Called when playback recovered after an error was shown.
  final void Function() onClear;

  Timer? _timer;
  String? _pending;
  String? _shown;

  /// True while an error is waiting out its grace period.
  bool get hasPending => _pending != null;

  /// The error currently shown, if any.
  String? get shownError => _shown;

  /// Reports an error from the player.
  ///
  /// Repeated reports restart the grace period, and empty messages are
  /// ignored.
  void report(String message) {
    if (message.isEmpty) return;
    _pending = message;
    _timer?.cancel();
    _timer = Timer(grace, _showPending);
  }

  /// Reports that playback is healthy again.
  ///
  /// Drops a pending error without showing it and dismisses a shown one.
  void recovered() {
    _pending = null;
    _timer?.cancel();
    _timer = null;
    if (_shown == null) return;
    _shown = null;
    onClear();
  }

  void _showPending() {
    _timer = null;
    final message = _pending;
    _pending = null;
    if (message == null) return;
    _shown = message;
    onShow(message);
  }

  /// Cancels timers and clears all state, e.g. when the overlay is disposed.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _shown = null;
  }
}
