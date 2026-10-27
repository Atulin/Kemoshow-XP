import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/ui/features/slideshow/views/widgets/post_body_view.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 400, child: child)),
      ),
    );
  }

  List<String> renderedText(WidgetTester tester) {
    return tester
        .widgetList<RichText>(find.byType(RichText))
        .map((richText) => richText.text.toPlainText())
        .toList();
  }

  testWidgets('renders paragraphs and inline emphasis', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PostBodyView(
          content:
              '<p>Hello <strong>bold</strong> and <em>italic</em>.</p>'
              '<p>Second paragraph</p>',
        ),
      ),
    );

    expect(renderedText(tester), [
      'Hello bold and italic.',
      'Second paragraph',
    ]);
  });

  testWidgets('collapses the whitespace of the source document', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const PostBodyView(content: '<p>one\n   two\tthree</p>')),
    );

    expect(renderedText(tester), ['one two three']);
  });

  testWidgets('ignores scripts, styles and other invisible content', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const PostBodyView(
          content:
              '<style>.a { color: red }</style>'
              '<script>alert("nope")</script>'
              '<p>Visible</p>',
        ),
      ),
    );

    final text = renderedText(tester).join('\n');
    expect(text, contains('Visible'));
    expect(text, isNot(contains('alert')));
    expect(text, isNot(contains('color')));
  });

  testWidgets('renders lists with markers', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PostBodyView(
          content:
              '<ul><li>First item</li><li>Second item</li></ul>'
              '<ol><li>Numbered</li></ol>',
        ),
      ),
    );

    final text = renderedText(tester);
    expect(
      text,
      containsAll(['•', 'First item', 'Second item', '1.', 'Numbered']),
    );
  });

  testWidgets('renders line breaks and block quotes', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PostBodyView(
          content:
              '<p>line one<br>line two</p>'
              '<blockquote>quoted</blockquote>',
        ),
      ),
    );

    final text = renderedText(tester);
    expect(text, contains('line one\nline two'));
    expect(text, contains('quoted'));
  });

  testWidgets('resolves relative image sources', (tester) async {
    await tester.pumpWidget(
      wrap(
        PostBodyView(
          content: '<p><img src="/data/aa/picture.jpg" alt="a picture"></p>',
          resolveUrl: (url) =>
              url.startsWith('/data/') ? 'https://n2.pawchive.pw$url' : url,
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://n2.pawchive.pw/data/aa/picture.jpg',
    );
  });

  testWidgets('makes links tappable', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      wrap(
        PostBodyView(
          content: '<p><a href="/patreon/user/1/post/2">link</a></p>',
          resolveUrl: (url) => 'https://pawchive.pw$url',
          onOpenLink: opened.add,
        ),
      ),
    );

    final rect = tester.getRect(find.byType(RichText).first);
    await tester.tapAt(rect.topLeft + const Offset(8, 8));
    await tester.pump();

    expect(opened.map((uri) => uri.toString()), [
      'https://pawchive.pw/patreon/user/1/post/2',
    ]);
  });

  testWidgets('renders tables row by row', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PostBodyView(
          content:
              '<table><tr><th>Name</th><th>Value</th></tr>'
              '<tr><td>one</td><td>two</td></tr></table>',
        ),
      ),
    );

    expect(renderedText(tester), ['Name', 'Value', 'one', 'two']);
  });

  testWidgets('renders nothing for an empty body', (tester) async {
    await tester.pumpWidget(wrap(const PostBodyView(content: '   ')));

    expect(find.byType(RichText), findsNothing);
  });
}
