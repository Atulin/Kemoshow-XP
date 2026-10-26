import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/ui/features/slideshow/views/widgets/image_slide.dart';

void main() {
  Widget buildSlide({VoidCallback? onTap, ValueChanged<bool>? onZoomChanged}) {
    return MaterialApp(
      home: Scaffold(
        body: ImageSlide(
          url: 'https://n2.pawchive.pw/data/aa/image.jpg',
          name: 'image.jpg',
          onTap: onTap,
          onZoomChanged: onZoomChanged,
        ),
      ),
    );
  }

  InteractiveViewer viewer(WidgetTester tester) {
    return tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
  }

  double scale(WidgetTester tester) {
    return viewer(tester).transformationController!.value.getMaxScaleOnAxis();
  }

  Future<void> doubleTap(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(ImageSlide));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
  }

  testWidgets('reports taps on the image', (tester) async {
    var taps = 0;
    await tester.pumpWidget(buildSlide(onTap: () => taps++));
    await tester.pump();

    await tester.tap(find.byType(ImageSlide));
    await tester.pump(const Duration(milliseconds: 400));

    expect(taps, 1);
  });

  testWidgets('double tap zooms in to the maximum and back out', (
    tester,
  ) async {
    final zoomChanges = <bool>[];
    await tester.pumpWidget(buildSlide(onZoomChanged: zoomChanges.add));
    await tester.pump();

    expect(scale(tester), 1.0);

    await doubleTap(tester);

    expect(scale(tester), closeTo(4.0, 0.001));
    expect(viewer(tester).panEnabled, isTrue);

    await doubleTap(tester);

    expect(scale(tester), closeTo(1.0, 0.001));
    expect(viewer(tester).panEnabled, isFalse);
    expect(zoomChanges, [true, false]);
  });

  testWidgets('pinching zooms in', (tester) async {
    await tester.pumpWidget(buildSlide());
    await tester.pump();

    final center = tester.getCenter(find.byType(ImageSlide));
    final first = await tester.startGesture(center - const Offset(50, 0));
    final second = await tester.startGesture(center + const Offset(50, 0));
    await tester.pump();

    await first.moveBy(const Offset(-100, 0));
    await second.moveBy(const Offset(100, 0));
    await tester.pump();

    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(scale(tester), greaterThan(1.0));
  });

  testWidgets('zoomed images can be panned', (tester) async {
    await tester.pumpWidget(buildSlide());
    await tester.pump();
    await doubleTap(tester);

    final controller = viewer(tester).transformationController!;
    final before = controller.value.getTranslation();
    final beforeX = before.x;
    final beforeY = before.y;

    await tester.drag(find.byType(ImageSlide), const Offset(-80, -40));
    await tester.pumpAndSettle();

    final after = controller.value.getTranslation();
    expect(after.x, isNot(closeTo(beforeX, 0.001)));
    expect(after.y, isNot(closeTo(beforeY, 0.001)));
  });

  testWidgets('leaves horizontal swipes to the pages while not zoomed', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageView.builder(
            controller: controller,
            itemCount: 3,
            itemBuilder: (context, index) => ImageSlide(
              url: 'https://n2.pawchive.pw/data/$index.jpg',
              name: '$index.jpg',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(controller.page, 1.0);
  });
}
