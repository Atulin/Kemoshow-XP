import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/ui/features/slideshow/views/widgets/image_slide.dart';

void main() {
  testWidgets('reports taps on the image', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ImageSlide(
          url: 'https://n2.pawchive.pw/data/aa/image.jpg',
          name: 'image.jpg',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(ImageSlide));
    await tester.pump();

    expect(taps, 1);
  });
}
