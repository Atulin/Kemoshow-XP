import 'package:flutter/foundation.dart';

import '../../../../data/services/settings_store.dart';
import '../../../../domain/models/app_settings.dart';

/// Exposes [AppSettings] to the UI and persists every change.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final SettingsStore _store;

  AppSettings _settings = AppSettings();
  bool _loaded = false;
  bool _disposed = false;
  Future<void> _writes = Future<void>.value();

  AppSettings get settings => _settings;

  /// Whether the persisted settings have been read. Until then the defaults
  /// are used.
  bool get isLoaded => _loaded;

  /// Reads the persisted settings. Failures fall back to the defaults.
  Future<void> load() async {
    AppSettings loaded;
    try {
      loaded = await _store.load();
    } catch (_) {
      loaded = AppSettings();
    }
    if (_disposed) return;
    _settings = loaded;
    _loaded = true;
    notifyListeners();
  }

  void setPreloadCount(int value) {
    final clamped = value < AppSettings.minPreloadCount
        ? AppSettings.minPreloadCount
        : (value > AppSettings.maxPreloadCount
              ? AppSettings.maxPreloadCount
              : value);
    if (clamped == _settings.preloadCount) return;
    _update(_settings.copyWith(preloadCount: clamped));
  }

  void setScanPostContent(bool value) {
    if (value == _settings.scanPostContent) return;
    _update(_settings.copyWith(scanPostContent: value));
  }

  void _update(AppSettings next) {
    _settings = next;
    _persist(next);
    notifyListeners();
  }

  /// Writes are chained so that a slow write cannot resurrect an old value.
  void _persist(AppSettings snapshot) {
    _writes = _writes.then((_) async {
      try {
        await _store.save(snapshot);
      } catch (error) {
        debugPrint('Could not save settings: $error');
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
