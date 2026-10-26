import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/repositories/kemono_repository.dart';
import 'package:kemoshow/data/services/kemono_api_service.dart';
import 'package:kemoshow/domain/models/favourite.dart';
import 'package:kemoshow/ui/features/favourites/view_models/favourites_controller.dart';
import 'package:kemoshow/ui/features/search/views/search_page.dart';
import 'package:kemoshow/ui/features/settings/view_models/settings_controller.dart';

import 'support/in_memory_favourites_store.dart';
import 'support/in_memory_settings_store.dart';

SettingsController _settingsController() {
  final controller = SettingsController(InMemorySettingsStore());
  addTearDown(controller.dispose);
  return controller;
}

FavouritesController _favouritesController([InMemoryFavouritesStore? store]) {
  final controller = FavouritesController(store ?? InMemoryFavouritesStore());
  addTearDown(controller.dispose);
  return controller;
}

KemonoRepository _repositoryWithCreators(List<Map<String, Object?>> creators) {
  return KemonoRepository(
    KemonoApiService(
      client: MockClient((_) async => http.Response(jsonEncode(creators), 200)),
      parseCreatorsInIsolate: false,
    ),
  );
}

void main() {
  testWidgets('author autocomplete filters the creator directory', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _repositoryWithCreators([
      {'id': '1', 'name': 'Alice', 'service': 'fanbox', 'favorited': 10},
      {'id': '2', 'name': 'Bob', 'service': 'patreon', 'favorited': 50},
    ]);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          repository: repository,
          settingsController: _settingsController(),
          favouritesController: _favouritesController(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('KemoShow'), findsOneWidget);
    expect(find.text('Post search'), findsOneWidget);

    await tester.tap(find.text('Author search'));
    await tester.pump();

    // Popular authors are sorted by favorite count.
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Popular authors'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ali');
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pump();

    expect(find.text('No authors match your search.'), findsOneWidget);
  });

  testWidgets('post search validates the minimum query length', (tester) async {
    final repository = _repositoryWithCreators(const []);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          repository: repository,
          settingsController: _settingsController(),
          favouritesController: _favouritesController(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(
      find.text('Enter at least 3 characters to search posts.'),
      findsOneWidget,
    );
  });

  testWidgets('settings dialog edits the configurable options', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _repositoryWithCreators(const []);
    addTearDown(repository.dispose);
    final controller = SettingsController(InMemorySettingsStore());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          repository: repository,
          settingsController: controller,
          favouritesController: _favouritesController(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Scan post descriptions for media'), findsOneWidget);
    expect(find.text('Preload ahead'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(controller.settings.scanPostContent, isTrue);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Scan post descriptions for media'), findsNothing);
  });

  testWidgets('post searches can be starred and removed from favourites', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _repositoryWithCreators(const []);
    addTearDown(repository.dispose);
    final store = InMemoryFavouritesStore();
    final favourites = FavouritesController(store);
    addTearDown(favourites.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          repository: repository,
          settingsController: _settingsController(),
          favouritesController: favourites,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), 'cats');
    await tester.pump();

    await tester.tap(find.byTooltip('Favourite this post search'));
    await tester.pump();

    const favourite = PostSearchFavourite(KemonoServer.defaultServer, 'cats');
    expect(favourites.favourites, [favourite]);
    expect(
      find.byTooltip('Remove post search from favourites'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Favourites'));
    await tester.pumpAndSettle();

    expect(find.text('Favourites'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'cats'), findsOneWidget);
    expect(find.text('Post search · pawchive.pw'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(favourites.favourites, isEmpty);
    expect(find.text('No favourites yet'), findsOneWidget);
  });

  testWidgets('saved favourites are listed with their server', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _repositoryWithCreators(const []);
    addTearDown(repository.dispose);
    final favourites = FavouritesController(
      InMemoryFavouritesStore(const [
        PostSearchFavourite(KemonoServer.kemono, 'old search'),
        AuthorFavourite(
          server: KemonoServer.coomer,
          id: '3',
          service: 'patreon',
          name: 'Carol',
        ),
      ]),
    );
    addTearDown(favourites.dispose);
    await favourites.load();

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          repository: repository,
          settingsController: _settingsController(),
          favouritesController: favourites,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Favourites'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'old search'), findsOneWidget);
    expect(find.text('Post search · kemono.cr'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Carol'), findsOneWidget);
    expect(find.text('patreon · coomer.su'), findsOneWidget);
  });

  testWidgets('authors can be starred from the results list', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _repositoryWithCreators([
      {'id': '1', 'name': 'Alice', 'service': 'fanbox', 'favorited': 10},
      {'id': '2', 'name': 'Bob', 'service': 'patreon', 'favorited': 50},
    ]);
    addTearDown(repository.dispose);
    final favourites = _favouritesController();

    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          repository: repository,
          settingsController: _settingsController(),
          favouritesController: favourites,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Author search'));
    await tester.pump();

    // Popular authors come first, so the first star belongs to Bob.
    await tester.tap(find.byTooltip('Add to favourites').first);
    await tester.pump();

    const bob = AuthorFavourite(
      server: KemonoServer.defaultServer,
      id: '2',
      service: 'patreon',
      name: 'Bob',
    );
    expect(favourites.favourites, [bob]);
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);

    await tester.tap(find.byTooltip('Favourites'));
    await tester.pumpAndSettle();

    final favouriteTile = find.ancestor(
      of: find.byIcon(Icons.delete_outline),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: favouriteTile, matching: find.text('Bob')),
      findsOneWidget,
    );
    expect(find.text('patreon · pawchive.pw'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(favourites.favourites, isEmpty);
    expect(find.text('No favourites yet'), findsOneWidget);
  });
}
