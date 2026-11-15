import 'package:flutter/material.dart';

import '../../../../core/kemono_server.dart';
import '../../favourites/view_models/favourites_controller.dart';
import '../view_models/server_controller.dart';

/// Opens the server management dialog.
Future<void> showServersDialog(
  BuildContext context,
  ServerController servers,
  FavouritesController favourites,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => ServersDialog(servers: servers, favourites: favourites),
  );
}

/// Lets the user add, edit and remove the servers KemoShow talks to.
///
/// These sites occasionally move to a new domain, so the bundled defaults are
/// only a starting point.
class ServersDialog extends StatelessWidget {
  const ServersDialog({
    super.key,
    required this.servers,
    required this.favourites,
  });

  final ServerController servers;
  final FavouritesController favourites;

  Future<void> _add(BuildContext context) async {
    final server = await _showEditDialog(context, initial: null);
    if (server == null || !context.mounted) return;
    if (!servers.add(server)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${server.host} is already configured.')),
      );
    }
  }

  Future<void> _edit(BuildContext context, KemonoServer old) async {
    final server = await _showEditDialog(context, initial: old);
    if (server == null || !context.mounted) return;
    if (!servers.update(old, server)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${server.host} is already configured.')),
      );
      return;
    }
    // Keep favourites reachable: they remember the server they were saved on.
    favourites.updateServer(old, server);
  }

  Future<void> _remove(BuildContext context, KemonoServer server) async {
    final favouriteCount = favourites.favourites
        .where((favourite) => favourite.server == server)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${server.host}?'),
        content: favouriteCount > 0
            ? Text(
                'This also removes $favouriteCount favourite'
                '${favouriteCount == 1 ? '' : 's'} saved on this server.',
              )
            : const Text(
                'The bundled servers can be added back by editing this list.',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    if (!servers.remove(server)) return;
    // Favourites on the removed server are no longer reachable.
    favourites.removeServer(server);
  }

  static Future<KemonoServer?> _showEditDialog(
    BuildContext context, {
    required KemonoServer? initial,
  }) {
    return showDialog<KemonoServer>(
      context: context,
      builder: (_) => _ServerEditDialog(initial: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: servers,
      builder: (context, _) {
        final list = servers.servers;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.dns_outlined, size: 22),
              SizedBox(width: 10),
              Text('Servers'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final server in list) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(server.host),
                      subtitle: Text(
                        'Media: ${server.dataHost} · Previews: ${server.previewHost}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit ${server.host}',
                            onPressed: () => _edit(context, server),
                            icon: const Icon(Icons.edit_outlined, size: 20),
                          ),
                          IconButton(
                            tooltip: list.length <= 1
                                ? 'The last server cannot be removed'
                                : 'Remove ${server.host}',
                            onPressed: list.length <= 1
                                ? null
                                : () => _remove(context, server),
                            icon: const Icon(Icons.delete_outline, size: 20),
                          ),
                        ],
                      ),
                    ),
                    if (server != list.last) const Divider(height: 1),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _add(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add server'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'These sites move between domains sometimes. Use the same '
                    'provider, just with the current host.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

/// Form for adding a new server or editing an existing one.
class _ServerEditDialog extends StatefulWidget {
  const _ServerEditDialog({required this.initial});

  final KemonoServer? initial;

  @override
  State<_ServerEditDialog> createState() => _ServerEditDialogState();
}

class _ServerEditDialogState extends State<_ServerEditDialog> {
  late final TextEditingController _host;
  late final TextEditingController _dataHost;
  late final TextEditingController _previewHost;
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _host = TextEditingController(text: initial?.host ?? '');
    _dataHost = TextEditingController(text: initial?.dataHost ?? '');
    _previewHost = TextEditingController(text: initial?.previewHost ?? '');
  }

  @override
  void dispose() {
    _host.dispose();
    _dataHost.dispose();
    _previewHost.dispose();
    super.dispose();
  }

  /// Keeps the derived hosts in sync with the site host while they are empty
  /// or still hold the previous suggestion.
  void _onHostChanged(String host) {
    final normalized = host.trim().toLowerCase();
    _syncDerived(_dataHost, 'n2', normalized);
    _syncDerived(_previewHost, 'img', normalized);
  }

  void _syncDerived(
    TextEditingController controller,
    String prefix,
    String host,
  ) {
    final current = controller.text.trim().toLowerCase();
    final previousHost = widget.initial?.host;
    final previousSuggestion = previousHost == null
        ? null
        : '$prefix.$previousHost';
    if (current.isEmpty || current == previousSuggestion) {
      controller.text = '$prefix.$host';
    }
  }

  String? _validateHost(String? value) {
    final host = value?.trim().toLowerCase() ?? '';
    if (host.isEmpty) return 'Enter a host, e.g. coomer.st.';
    if (!KemonoServer.isValidHost(host)) {
      return 'Not a valid host, e.g. coomer.st.';
    }
    return null;
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      KemonoServer(
        host: _host.text.trim().toLowerCase(),
        dataHost: _dataHost.text.trim().toLowerCase(),
        previewHost: _previewHost.text.trim().toLowerCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.dns_outlined, size: 22),
          const SizedBox(width: 10),
          Text(isNew ? 'Add server' : 'Edit ${widget.initial!.host}'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _host,
                decoration: const InputDecoration(
                  labelText: 'Site host',
                  hintText: 'coomer.st',
                ),
                textInputAction: TextInputAction.next,
                validator: _validateHost,
                onChanged: _onHostChanged,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dataHost,
                decoration: const InputDecoration(
                  labelText: 'Media host',
                  helperText: 'Serves files under /data/, e.g. n3.coomer.st.',
                ),
                textInputAction: TextInputAction.next,
                validator: _validateHost,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _previewHost,
                decoration: const InputDecoration(
                  labelText: 'Preview host',
                  helperText:
                      'Serves thumbnails under /thumbnail/data/, e.g. '
                      'img.coomer.st.',
                ),
                validator: _validateHost,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
