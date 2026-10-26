import 'package:flutter/material.dart';

import '../../../../domain/models/favourite.dart';
import '../view_models/favourites_controller.dart';

/// Bottom sheet listing the saved favourites.
///
/// Pops with the tapped favourite so the caller can open it after the sheet is
/// gone. Rows can be deleted in place.
class FavouritesSheet extends StatelessWidget {
  const FavouritesSheet({super.key, required this.controller});

  final FavouritesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        // Shrink to the content height, but centre and cap the width on desktop
        // so the list does not stretch across the whole window.
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final favourites = controller.favourites;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Row(
                      children: [
                        Text('Favourites', style: theme.textTheme.titleLarge),
                        const Spacer(),
                        if (favourites.isNotEmpty)
                          Text(
                            '${favourites.length}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (favourites.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                      child: Column(
                        children: [
                          Icon(
                            Icons.star_border,
                            size: 44,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No favourites yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Star a post search or an author to keep it here.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                        itemCount: favourites.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final favourite = favourites[index];
                          final isPostSearch = favourite is PostSearchFavourite;
                          final subtitle = switch (favourite) {
                            PostSearchFavourite() =>
                              'Post search · ${favourite.server.host}',
                            AuthorFavourite() =>
                              '${favourite.service} · ${favourite.server.host}',
                          };

                          return ListTile(
                            onTap: () => Navigator.of(context).pop(favourite),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor:
                                  theme.colorScheme.onPrimaryContainer,
                              child: Icon(
                                isPostSearch
                                    ? Icons.article_outlined
                                    : Icons.person_outline,
                              ),
                            ),
                            title: Text(
                              favourite.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove from favourites',
                              onPressed: () => controller.remove(favourite),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
