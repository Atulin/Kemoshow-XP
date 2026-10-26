import 'package:flutter/material.dart';

/// Shows the keyboard shortcut reference as a dialog.
Future<void> showShortcutsHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const ShortcutsHintDialog(),
  );
}

/// Dialog listing all keyboard bindings of the slideshow.
class ShortcutsHintDialog extends StatelessWidget {
  const ShortcutsHintDialog({super.key});

  static const _shortcuts = <(String, String)>[
    ('← / →  ·  A / D', 'Previous / next media'),
    ('Space  ·  K', 'Play or pause the video'),
    ('↑ / ↓  ·  W / S', 'Seek 5 seconds'),
    ('J / L', 'Seek 10 seconds'),
    ('Shift + ← / →', 'Seek 30 seconds'),
    ('M', 'Mute / unmute'),
    ('Home / End', 'First / last loaded media'),
    ('H  ·  ?', 'Show this help'),
    ('Esc', 'Back to search'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (keys, description) in _shortcuts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        keys,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
