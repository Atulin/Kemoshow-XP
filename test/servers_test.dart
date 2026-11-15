import 'package:flutter_test/flutter_test.dart';
import 'package:kemoshow/core/kemono_server.dart';
import 'package:kemoshow/data/services/server_store.dart';
import 'package:kemoshow/ui/features/servers/view_models/server_controller.dart';

import 'support/in_memory_server_store.dart';

void main() {
  group('ServerController', () {
    test('uses the bundled servers until nothing is persisted', () async {
      final controller = ServerController();
      addTearDown(controller.dispose);

      expect(controller.isLoaded, isFalse);
      expect(controller.servers, KemonoServer.bundledServers);
      expect(controller.selectedServer, KemonoServer.defaultServer);

      await controller.load();
      expect(controller.isLoaded, isTrue);
      // Without a store there is nothing to read; the defaults remain.
      expect(controller.servers, KemonoServer.bundledServers);
    });

    test('restores the persisted servers and selection', () async {
      const custom = KemonoServer(
        host: 'coomer.example',
        dataHost: 'n3.coomer.example',
        previewHost: 'img.coomer.example',
      );
      final controller = ServerController(
        InMemoryServerStore(
          ServerState(
            servers: [KemonoServer.pawchive, custom],
            selectedHost: custom.host,
          ),
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.servers, [KemonoServer.pawchive, custom]);
      expect(controller.selectedServer, custom);
    });

    test(
      'falls back to the first server when the selection disappeared',
      () async {
        const custom = KemonoServer(
          host: 'coomer.example',
          dataHost: 'n3.coomer.example',
          previewHost: 'img.coomer.example',
        );
        final controller = ServerController(
          InMemoryServerStore(
            ServerState(
              servers: [KemonoServer.pawchive, custom],
              selectedHost: 'gone.example.com',
            ),
          ),
        );
        addTearDown(controller.dispose);

        await controller.load();
        expect(controller.selectedServer, KemonoServer.pawchive);
      },
    );

    test('add, select and remove maintain the server list', () async {
      final store = InMemoryServerStore();
      final controller = ServerController(store);
      addTearDown(controller.dispose);

      const custom = KemonoServer(
        host: 'coomer.example',
        dataHost: 'n3.coomer.example',
        previewHost: 'img.coomer.example',
      );

      expect(controller.add(custom), isTrue);
      expect(controller.servers.length, 4);
      await pumpEventQueue();
      expect(store.saveCount, 1);

      expect(controller.select(custom), isTrue);
      expect(controller.selectedServer, custom);

      // Selecting a server that is not in the list changes nothing.
      expect(
        controller.select(
          const KemonoServer(
            host: 'unknown.example',
            dataHost: 'n1.unknown.example',
            previewHost: 'img.unknown.example',
          ),
        ),
        isFalse,
      );
      expect(controller.selectedServer, custom);

      expect(controller.remove(custom), isTrue);
      expect(controller.servers.length, 3);
      // The selected server was removed, so the first one is selected.
      expect(controller.selectedServer, KemonoServer.pawchive);
    });

    test('rejects duplicate servers and the removal of the last one', () async {
      final controller = ServerController();
      addTearDown(controller.dispose);

      expect(
        controller.add(
          KemonoServer(
            host: 'PAWCHIVE.PW',
            dataHost: 'n9.pawchive.pw',
            previewHost: 'img.pawchive.pw',
          ),
        ),
        isFalse,
      );

      controller.select(KemonoServer.kemono);
      expect(controller.remove(KemonoServer.pawchive), isTrue);
      expect(controller.remove(KemonoServer.kemono), isTrue);
      expect(controller.servers, [KemonoServer.coomer]);
      expect(controller.selectedServer, KemonoServer.coomer);
      expect(controller.remove(KemonoServer.coomer), isFalse);
    });

    test('update replaces a server and keeps the selection', () async {
      final controller = ServerController();
      addTearDown(controller.dispose);
      controller.select(KemonoServer.coomer);

      const moved = KemonoServer(
        host: 'coomer.example',
        dataHost: 'n3.coomer.example',
        previewHost: 'img.coomer.example',
      );
      expect(controller.update(KemonoServer.coomer, moved), isTrue);
      expect(controller.servers, [
        KemonoServer.pawchive,
        KemonoServer.kemono,
        moved,
      ]);
      expect(controller.selectedServer, moved);

      // Renaming onto an existing site host is refused.
      expect(
        controller.update(
          moved,
          const KemonoServer(
            host: 'pawchive.pw',
            dataHost: 'other.pawchive.pw',
            previewHost: 'img.pawchive.pw',
          ),
        ),
        isFalse,
      );
      expect(controller.selectedServer, moved);
    });

    test('does not persist without a store', () {
      final controller = ServerController();
      addTearDown(controller.dispose);

      controller.add(
        const KemonoServer(
          host: 'coomer.example',
          dataHost: 'n3.coomer.example',
          previewHost: 'img.coomer.example',
        ),
      );
      // No store, no crash: the change only lives in memory.
      expect(controller.servers.length, 4);
    });
  });

  group('KemonoServer serialization', () {
    test('round-trips through JSON', () {
      const server = KemonoServer(
        host: 'coomer.example',
        dataHost: 'n3.coomer.example',
        previewHost: 'img.coomer.example',
      );
      expect(KemonoServer.tryParse(server.toJson()), server);
    });

    test('rejects malformed entries', () {
      expect(KemonoServer.tryParse(null), isNull);
      expect(KemonoServer.tryParse(<String, Object?>{}), isNull);
      expect(
        KemonoServer.tryParse(<String, Object?>{
          'host': 'coomer.example',
          'dataHost': 'not a host!',
          'previewHost': 'img.coomer.example',
        }),
        isNull,
      );
    });

    test('matches hosts case-insensitively', () {
      expect(KemonoServer.fromHost('COOMER.ST'), KemonoServer.coomer);
      expect(KemonoServer.fromHost('example.com'), isNull);
    });

    test('validates hostnames', () {
      expect(KemonoServer.isValidHost('coomer.example'), isTrue);
      expect(KemonoServer.isValidHost('n3.coomer.example'), isTrue);
      expect(KemonoServer.isValidHost('coomer'), isFalse);
      expect(KemonoServer.isValidHost('coomer..st'), isFalse);
      expect(KemonoServer.isValidHost(''), isFalse);
    });
  });
}
