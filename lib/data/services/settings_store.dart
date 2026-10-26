import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_settings.dart';

/// Persists [AppSettings] across app runs.
abstract interface class SettingsStore {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

/// Stores the settings in the platform's shared preferences.
class SharedPreferencesSettingsStore implements SettingsStore {
  static const String _preloadCountKey = 'slideshow.preload_count';
  static const String _scanPostContentKey = 'slideshow.scan_post_content';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      preloadCount:
          prefs.getInt(_preloadCountKey) ?? AppSettings.defaultPreloadCount,
      scanPostContent: prefs.getBool(_scanPostContentKey) ?? false,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_preloadCountKey, settings.preloadCount);
    await prefs.setBool(_scanPostContentKey, settings.scanPostContent);
  }
}
