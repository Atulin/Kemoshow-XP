import 'package:flutter/material.dart';

import '../../../../domain/models/app_settings.dart';
import '../view_models/settings_controller.dart';

/// Opens the settings dialog.
Future<void> showSettingsDialog(
  BuildContext context,
  SettingsController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => SettingsDialog(controller: controller),
  );
}

/// Slideshow preferences: post-body scanning and image preloading.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings_outlined, size: 22),
              SizedBox(width: 10),
              Text('Settings'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Scan post descriptions for media'),
                    subtitle: const Text(
                      'Adds links that point directly to an image or video '
                      '(.png, .jpg, .gif, .mp4, …) to the slideshow. Attachments '
                      'are always included. Post search results usually omit '
                      'post descriptions, so this mainly affects author '
                      'slideshows.',
                    ),
                    value: settings.scanPostContent,
                    onChanged: controller.setScanPostContent,
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Preload ahead'),
                    subtitle: const Text(
                      'Loads upcoming images in the background so swiping feels '
                      'instant. Videos are opened when they become visible.',
                    ),
                    trailing: Text(
                      '${settings.preloadCount}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Slider(
                      value: settings.preloadCount.toDouble(),
                      min: AppSettings.minPreloadCount.toDouble(),
                      max: AppSettings.maxPreloadCount.toDouble(),
                      divisions:
                          AppSettings.maxPreloadCount -
                          AppSettings.minPreloadCount,
                      label: '${settings.preloadCount} media',
                      onChanged: (value) =>
                          controller.setPreloadCount(value.round()),
                    ),
                  ),
                  Text(
                    settings.preloadCount == 0
                        ? 'Preloading is disabled.'
                        : 'Up to ${settings.preloadCount} upcoming media items '
                              'are preloaded.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
