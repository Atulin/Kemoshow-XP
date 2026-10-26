import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/domain/models/app_settings.dart';
import 'package:kemoshow/ui/features/settings/view_models/settings_controller.dart';

import 'support/in_memory_settings_store.dart';

void main() {
  group('AppSettings', () {
    test('clamps the preload count on construction', () {
      expect(AppSettings(preloadCount: -5).preloadCount, 0);
      expect(AppSettings(preloadCount: 42).preloadCount, 10);
      expect(AppSettings(preloadCount: 4).preloadCount, 4);
    });

    test('uses sane defaults', () {
      final settings = AppSettings();
      expect(settings.preloadCount, AppSettings.defaultPreloadCount);
      expect(settings.scanPostContent, isFalse);
    });
  });

  group('SettingsController', () {
    test('starts with defaults before loading', () {
      final controller = SettingsController(InMemorySettingsStore());
      addTearDown(controller.dispose);

      expect(controller.isLoaded, isFalse);
      expect(controller.settings, AppSettings());
    });

    test('loads persisted values', () async {
      final store = InMemorySettingsStore(
        AppSettings(preloadCount: 6, scanPostContent: true),
      );
      final controller = SettingsController(store);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(controller.settings.preloadCount, 6);
      expect(controller.settings.scanPostContent, isTrue);
    });

    test('falls back to defaults when loading fails', () async {
      final controller = SettingsController(_FailingStore());
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.settings, AppSettings());
      expect(controller.isLoaded, isTrue);
    });

    test('clamps and persists changed values', () async {
      final store = InMemorySettingsStore();
      final controller = SettingsController(store);
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setPreloadCount(25);
      controller.setPreloadCount(-1);
      controller.setScanPostContent(true);
      await pumpEventQueue();

      expect(controller.settings.preloadCount, 0);
      expect(controller.settings.scanPostContent, isTrue);
      expect(notifications, 3);
      expect(store.settings, controller.settings);
      expect(store.saveCount, 3);
    });

    test('does not notify or save when nothing changes', () async {
      final store = InMemorySettingsStore();
      final controller = SettingsController(store);
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setPreloadCount(AppSettings.defaultPreloadCount);
      controller.setScanPostContent(false);
      await pumpEventQueue();

      expect(notifications, 0);
      expect(store.saveCount, 0);
    });
  });
}

class _FailingStore extends InMemorySettingsStore {
  @override
  Future<AppSettings> load() async => throw StateError('unavailable');
}
