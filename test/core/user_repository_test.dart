import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/core/user/user_database.dart';
import 'package:stoic_quotes/core/user/user_repository.dart';

void main() {
  late UserRepository repo;

  setUp(() => repo = UserRepository(openTestUserDatabase()));
  tearDown(() => repo.close());

  test('favorites: add, toggle, remove, newest first', () async {
    await repo.addFavorite('ma-4-3-a');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.addFavorite('sen-13-4-a');
    expect(await repo.watchFavoriteIds().first, ['sen-13-4-a', 'ma-4-3-a']);
    await repo.toggleFavorite('ma-4-3-a');
    expect(await repo.isFavorite('ma-4-3-a'), isFalse);
    await repo.toggleFavorite('ma-4-3-a');
    expect(await repo.isFavorite('ma-4-3-a'), isTrue);
    await repo.removeFavorite('sen-13-4-a');
    expect(await repo.watchFavoriteIds().first, ['ma-4-3-a']);
  });

  test('adding the same favorite twice keeps one row', () async {
    await repo.addFavorite('ma-4-3-a');
    await repo.addFavorite('ma-4-3-a');
    expect(await repo.watchFavoriteIds().first, ['ma-4-3-a']);
  });

  test('seen quotes and settings', () async {
    await repo.markSeen('a');
    await repo.markSeen('b');
    await repo.markSeen('a');
    expect(await repo.seenQuoteIds(), {'a', 'b'});
    await repo.clearSeen();
    expect(await repo.seenQuoteIds(), isEmpty);
    expect(await repo.setting('x'), isNull);
    await repo.setSetting('x', '1');
    await repo.setSetting('x', '2');
    expect(await repo.setting('x'), '2');
  });

  test('legacy favorites', () async {
    await repo.addLegacyFavorite('Old quote', 'Someone');
    final rows = await repo.watchLegacyFavorites().first;
    expect(rows.single.quote, 'Old quote');
    await repo.removeLegacyFavorite(rows.single.id);
    expect(await repo.watchLegacyFavorites().first, isEmpty);
  });

  test('a key that is not 64 hex characters is rejected', () {
    expect(
      () => openUserDatabase(File('unused.db'), 'short'),
      throwsA(anything),
    );
  });

  test('focus picks keep their order; the intro is seen once marked', () async {
    expect(await repo.focusAreaIds(), isEmpty);
    expect(await repo.introSeen(), isFalse);
    await repo.setFocusAreaIds(['loss', 'pushing-further', 'calm']);
    expect(await repo.focusAreaIds(), ['loss', 'pushing-further', 'calm']);
    expect(await repo.watchFocusAreaIds().first, [
      'loss',
      'pushing-further',
      'calm',
    ]);
    await repo.setFocusAreaIds([]);
    expect(await repo.focusAreaIds(), isEmpty);
    await repo.markIntroSeen();
    expect(await repo.introSeen(), isTrue);
  });
}
