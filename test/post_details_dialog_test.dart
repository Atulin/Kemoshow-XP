import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/models/post.dart';
import 'package:kemoshow/ui/features/slideshow/views/widgets/post_details_dialog.dart';

void main() {
  const post = Post(
    id: '77447876',
    user: '2613194',
    service: 'patreon',
    title: 'Jan2023 Icaro: 02',
    content: '<p>Judy from <strong>Zootopia</strong></p>',
    published: '2023-01-19T09:13:11',
  );

  Widget wrap({
    required Post post,
    required void Function(BuildContext) onOpen,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onOpen(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(
    WidgetTester tester, {
    required Post post,
    KemonoServer server = KemonoServer.pawchive,
    Future<bool> Function(Uri url)? openUrl,
    Future<Post?> Function()? loadDetails,
  }) async {
    final opener = openUrl ?? (_) async => true;
    await tester.pumpWidget(
      wrap(
        post: post,
        onOpen: (context) => showPostDetails(
          context,
          post: post,
          server: server,
          openUrl: opener,
          loadDetails: loadDetails,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the full title, metadata and rendered body', (
    tester,
  ) async {
    await openDialog(tester, post: post);

    expect(find.text('Jan2023 Icaro: 02'), findsOneWidget);
    expect(find.text('patreon · 2613194 · 2023-01-19'), findsOneWidget);
    expect(
      find.textContaining('Judy from Zootopia', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Open post'), findsOneWidget);
  });

  testWidgets('opens the post in the browser', (tester) async {
    final opened = <Uri>[];
    await openDialog(
      tester,
      post: post,
      openUrl: (url) async {
        opened.add(url);
        return true;
      },
    );

    await tester.tap(find.text('Open post'));
    await tester.pump();

    expect(opened.map((uri) => uri.toString()), [
      'https://pawchive.pw/patreon/user/2613194/post/77447876',
    ]);
  });

  testWidgets('warns when the browser could not be opened', (tester) async {
    await openDialog(tester, post: post, openUrl: (_) async => false);

    await tester.tap(find.text('Open post'));
    await tester.pump();

    expect(
      find.text('Could not open the post in the browser.'),
      findsOneWidget,
    );
  });

  testWidgets('disables opening a post without a service or creator', (
    tester,
  ) async {
    var calls = 0;
    await openDialog(
      tester,
      post: const Post(id: '1'),
      openUrl: (_) async {
        calls++;
        return true;
      },
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(calls, 0);
    expect(find.text('Untitled post'), findsOneWidget);
  });

  testWidgets('shows a note for posts without a body', (tester) async {
    await openDialog(
      tester,
      post: const Post(
        id: '2',
        service: 'patreon',
        user: '1',
        title: 'Only media',
      ),
    );

    expect(find.text('This post has no text.'), findsOneWidget);
  });

  testWidgets('lays out long bodies on a phone screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await openDialog(
      tester,
      post: const Post(
        id: '3',
        service: 'patreon',
        user: '1',
        title:
            'A very long post title that does not fit on one line of the '
            'slideshow header, and therefore needs to wrap in the dialog',
        content:
            '<p>An opening paragraph that is long enough to wrap over several '
            'lines on a narrow screen, which is the common case.</p>'
            '<ul><li>first</li><li>second</li></ul>'
            '<blockquote>quoted text</blockquote>'
            '<pre>code\n  block</pre>'
            '<hr>'
            '<table><tr><th>a</th><th>b</th></tr></table>',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Open post'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('loads the body when the post has none', (tester) async {
    final requested = <String>[];

    await openDialog(
      tester,
      post: const Post(
        id: '4',
        service: 'patreon',
        user: '1',
        title: 'Listing without a body',
      ),
      loadDetails: () async {
        requested.add('4');
        return const Post(
          id: '4',
          service: 'patreon',
          user: '1',
          title: 'Listing without a body',
          content: '<p>Fetched <em>body</em></p>',
        );
      },
    );

    expect(requested, ['4']);
    expect(
      find.textContaining('Fetched body', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('This post has no text.'), findsNothing);
    expect(find.text('Loading post…'), findsNothing);
  });

  testWidgets('offers a retry when the body cannot be loaded', (tester) async {
    var attempts = 0;

    await openDialog(
      tester,
      post: const Post(
        id: '5',
        service: 'patreon',
        user: '1',
        title: 'Flaky post',
      ),
      loadDetails: () async {
        attempts++;
        if (attempts == 1) return null;
        return const Post(
          id: '5',
          service: 'patreon',
          user: '1',
          title: 'Flaky post',
          content: '<p>Loaded on retry</p>',
        );
      },
    );

    expect(attempts, 1);
    expect(find.text('Could not load the post body.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Could not load the post body.'), findsNothing);
    expect(
      find.textContaining('Loaded on retry', findRichText: true),
      findsOneWidget,
    );
  });
}
