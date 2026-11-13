/// App wide Riverpod providers. Tests override them with fakes.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/content/content_repository.dart';
import '../core/reflection_service.dart';
import '../core/user/key_store.dart';
import '../core/user/legacy_migration.dart';
import '../core/user/user_database.dart';
import '../core/user/user_repository.dart';

final contentProvider = FutureProvider<Content>((ref) => loadContent());

final userRepositoryProvider = FutureProvider<UserRepository>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final key = await loadOrCreateDatabaseKey();
  final repo = UserRepository(
    openUserDatabase(File(p.join(dir.path, 'user.db')), key),
  );
  ref.onDispose(repo.close);
  // One time import from the first app version; never blocks on failure.
  try {
    final content = await ref.watch(contentProvider.future);
    await migrateLegacyFavorites(
      repository: repo,
      content: content,
      oldDatabase: File(
        p.join(p.dirname(dir.path), 'databases', 'favorites.db'),
      ),
    );
  } on Object catch (e) {
    debugPrint('legacy favorites not migrated: ${e.runtimeType}');
  }
  return repo;
});

/// Loads the model in the background; the Reflect screen waits for it.
final reflectionFinderProvider = FutureProvider<ReflectionFinder>((ref) async {
  final content = await ref.watch(contentProvider.future);
  return loadReflectionService(content);
});

final favoriteIdsProvider = StreamProvider<List<String>>((ref) async* {
  final repo = await ref.watch(userRepositoryProvider.future);
  yield* repo.watchFavoriteIds();
});

final legacyFavoritesProvider = StreamProvider<List<LegacyFavorite>>((
  ref,
) async* {
  final repo = await ref.watch(userRepositoryProvider.future);
  yield* repo.watchLegacyFavorites();
});

/// The person's focus picks (ids from focus_areas.dart), in pick order.
final focusAreaIdsProvider = StreamProvider<List<String>>((ref) async* {
  final repo = await ref.watch(userRepositoryProvider.future);
  yield* repo.watchFocusAreaIds();
});
