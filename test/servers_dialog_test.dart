import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/services/server_store.dart';
import 'package:kemoshow/domain/models/favourite.dart';
import 'package:kemoshow/ui/features/favourites/view_models/favourites_controller.dart';
import 'package:kemoshow/ui/features/servers/view_models/server_controller.dart';
import 'package:kemoshow/ui/features/servers/views/servers_dialog.dart';

import 'support/in_memory_favourites_store.dart';
import 'support/in_memory_server_store.dart';

void main() {
  Future<(ServerController, FavouritesController)> pumpDialog(
    WidgetTester tester, {
    InMemoryFavouritesStore? favouritesStore,
  }) async {
    final servers = ServerController(InMemoryServerStore());
    final favourites = FavouritesController(
      favouritesStore ?? InMemoryFavouritesStore(),
    );
    await favourites.load(servers: servers.servers);
    addTearDown(servers.dispose);
    addTearDown(favourites.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    showServersDialog(context, servers, favourites),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (servers, favourites);
  }

  testWidgets('lists the configured servers', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('pawchive.pw'), findsOneWidget);
    expect(find.text('kemono.cr'), findsOneWidget);
    expect(find.text('coomer.su'), findsOneWidget);
  });

  testWidgets('a new server can be added and appears in the list', (
    tester,
  ) async {
    final (servers, _) = await pumpDialog(tester);

    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'coomer.st');
    await tester.enterText(find.byType(TextFormField).at(1), 'n3.coomer.st');
    await tester.enterText(find.byType(TextFormField).at(2), 'img.coomer.st');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('coomer.st'), findsOneWidget);
    expect(servers.servers.map((server) => server.host), contains('coomer.st'));
  });

  testWidgets('media and preview hosts are suggested from the site host', (
    tester,
  ) async {
    final (servers, _) = await pumpDialog(tester);

    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'coomer.st');
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'n2.coomer.st'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'img.coomer.st'), findsOneWidget);

    // The suggested values produce a valid server.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      servers.servers.last,
      const KemonoServer(
        host: 'coomer.st',
        dataHost: 'n2.coomer.st',
        previewHost: 'img.coomer.st',
      ),
    );
  });

  testWidgets('adding an empty host is rejected', (tester) async {
    final (servers, _) = await pumpDialog(tester);

    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a host, e.g. coomer.st.'), findsNWidgets(3));
    expect(find.text('Save'), findsOneWidget);
    expect(servers.servers.length, 3);
  });

  testWidgets('editing a server moves its favourites along', (tester) async {
    final (servers, favourites) = await pumpDialog(
      tester,
      favouritesStore: InMemoryFavouritesStore([
        const PostSearchFavourite(KemonoServer.coomer, 'old search'),
      ]),
    );

    await tester.tap(find.byTooltip('Edit coomer.su'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'coomer.st');
    await tester.enterText(find.byType(TextFormField).at(1), 'n3.coomer.st');
    await tester.enterText(find.byType(TextFormField).at(2), 'img.coomer.st');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('coomer.st'), findsOneWidget);
    // Another server was edited, so the selection is untouched.
    expect(servers.selectedServer, KemonoServer.defaultServer);
    expect(favourites.favourites.single.server.host, 'coomer.st');
  });

  testWidgets('removing a server asks for confirmation and drops its '
      'favourites', (tester) async {
    final (servers, favourites) = await pumpDialog(
      tester,
      favouritesStore: InMemoryFavouritesStore([
        const PostSearchFavourite(KemonoServer.coomer, 'old search'),
      ]),
    );

    await tester.tap(find.byTooltip('Remove coomer.su'));
    await tester.pumpAndSettle();
    expect(
      find.text('This also removes 1 favourite saved on this server.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('coomer.su'), findsNothing);
    expect(servers.servers.length, 2);
    expect(favourites.favourites, isEmpty);
  });

  testWidgets('the last remaining server cannot be removed', (tester) async {
    final store = InMemoryServerStore(
      ServerState(
        servers: const [KemonoServer.coomer],
        selectedHost: 'coomer.su',
      ),
    );
    final servers = ServerController(store);
    final favourites = FavouritesController(InMemoryFavouritesStore());
    await servers.load();
    await favourites.load(servers: servers.servers);
    addTearDown(servers.dispose);
    addTearDown(favourites.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    showServersDialog(context, servers, favourites),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final delete = find.byTooltip('The last server cannot be removed');
    expect(delete, findsOneWidget);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(servers.servers.length, 1);
  });
}
