import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/ui/features/slideshow/views/widgets/video_overlay_surface.dart';

void main() {
  late PageController controller;

  setUp(() => controller = PageController());
  tearDown(() => controller.dispose());

  Widget build({
    VoidCallback? onTap,
    VoidCallback? onHover,
    VoidCallback? onPlay,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: controller,
              itemCount: 3,
              itemBuilder: (context, index) =>
                  ColoredBox(color: index.isEven ? Colors.grey : Colors.blue),
            ),
            // Mirrors how the slideshow stacks the video overlay above its
            // pages.
            Positioned.fill(
              child: VideoOverlaySurface(
                onTap: onTap ?? () {},
                onHover: (_) => onHover?.call(),
                child: Stack(
                  children: [
                    if (onPlay != null)
                      Center(
                        child: IconButton(
                          tooltip: 'Play',
                          onPressed: onPlay,
                          icon: const Icon(Icons.play_arrow),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('stays translucent to hit testing', (tester) async {
    await tester.pumpWidget(build());

    final region = tester.widget<MouseRegion>(
      find
          .descendant(
            of: find.byType(VideoOverlaySurface),
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(region.hitTestBehavior, HitTestBehavior.translucent);
  });

  testWidgets('does not swallow horizontal swipes of the pages below', (
    tester,
  ) async {
    await tester.pumpWidget(build());

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(controller.page, 1.0);
  });

  testWidgets('swipes back to the previous page as well', (tester) async {
    await tester.pumpWidget(build());
    controller.jumpToPage(1);
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(controller.page, 0.0);
  });

  testWidgets('tapping the video triggers the tap handler', (tester) async {
    var taps = 0;
    await tester.pumpWidget(build(onTap: () => taps++));

    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('controls inside the surface still receive taps', (tester) async {
    var taps = 0;
    var plays = 0;
    await tester.pumpWidget(build(onTap: () => taps++, onPlay: () => plays++));

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(plays, 1);
    expect(taps, 0);
  });
}
