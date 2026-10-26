import 'package:kemoshow/data/services/settings_store.dart';
import 'package:kemoshow/domain/models/app_settings.dart';

/// In-memory [SettingsStore] for tests.
class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([AppSettings? initial])
    : settings = initial ?? AppSettings();

  AppSettings settings;
  int saveCount = 0;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> save(AppSettings value) async {
    settings = value;
    saveCount++;
  }
}
