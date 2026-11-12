import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/user/user_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
    final repo = await ref.read(userRepositoryProvider.future);
    await repo.removeFavorite(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed from favorites'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.addFavorite(id),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final content = ref.watch(contentProvider).value;
    final ids = ref.watch(favoriteIdsProvider);
    final legacy =
        ref.watch(legacyFavoritesProvider).value ?? const <LegacyFavorite>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          IconButton(
            tooltip: 'About and safety',
            onPressed: () => context.push('/about'),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: switch (ids) {
        AsyncData(value: final list) when content != null =>
          list.isEmpty && legacy.isEmpty
              ? const _Empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    for (final id in list)
                      if (content.quote(id) case final q?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Dismissible(
                            key: ValueKey(id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(
                                color: AppColors.heart.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: AppColors.heart,
                              ),
                            ),
                            onDismissed: (_) => _remove(context, ref, id),
                            child: Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.fromLTRB(
                                  18,
                                  10,
                                  8,
                                  10,
                                ),
                                title: Text(
                                  q.explanation,
                                  style: theme.textTheme.titleSmall,
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${q.author} · ${q.citation}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.amberSoft,
                                    ),
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: 'Remove from favorites',
                                  onPressed: () => _remove(context, ref, id),
                                  icon: const Icon(
                                    Icons.favorite,
                                    color: AppColors.heart,
                                  ),
                                ),
                                onTap: () => context.push('/quote/$id'),
                              ),
                            ),
                          ),
                        ),
                    if (legacy.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'From the first version of the app',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        'These were saved before quotes had sources, so no source is shown.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final f in legacy)
                        Card(
                          child: ListTile(
                            title: Text(
                              f.quote,
                              style: const TextStyle(
                                fontFamily: 'Lora',
                                fontStyle: FontStyle.italic,
                                color: AppColors.amber,
                              ),
                            ),
                            subtitle: Text(f.author),
                            trailing: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final repo = await ref.read(
                                  userRepositoryProvider.future,
                                );
                                await repo.removeLegacyFavorite(f.id);
                              },
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        AsyncError() => const Center(
          child: Text('Could not open your favorites.'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border, size: 48, color: AppColors.heart),
            const SizedBox(height: 16),
            Text('No favorites yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Tap the heart on any quote to keep it here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
