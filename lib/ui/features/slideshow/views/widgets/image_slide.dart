import 'package:flutter/material.dart';

/// A zoom-free, contained network image with loading and error states.
class ImageSlide extends StatefulWidget {
  const ImageSlide({super.key, required this.url, required this.name});

  final String url;
  final String name;

  @override
  State<ImageSlide> createState() => _ImageSlideState();
}

class _ImageSlideState extends State<ImageSlide> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      image: true,
      label: widget.name,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Image.network(
            widget.url,
            key: ValueKey(_attempt),
            fit: BoxFit.contain,
            gaplessPlayback: false,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              final total = progress.expectedTotalBytes;
              final value = total == null || total == 0
                  ? null
                  : progress.cumulativeBytesLoaded / total;
              return Center(
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 3,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    const Text('Could not load this image.'),
                    const SizedBox(height: 4),
                    Text(
                      widget.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _attempt++),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
