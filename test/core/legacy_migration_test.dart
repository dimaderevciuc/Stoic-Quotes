import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:stoic_quotes/core/user/legacy_migration.dart';
import 'package:stoic_quotes/core/user/user_database.dart';
import 'package:stoic_quotes/core/user/user_repository.dart';

import '../helpers.dart';

void main() {
  test(
    'old favorites are imported once and the old file is left alone',
    () async {
      final content = loadContentFromDisk();
      final dir = await Directory.systemTemp.createTemp('stoic');
      addTearDown(() => dir.delete(recursive: true));
      final old = File('${dir.path}/favorites.db');
      final db = sqlite3.open(old.path)
        ..execute(
          'CREATE TABLE favorites (id INTEGER PRIMARY KEY AUTOINCREMENT, quote TEXT, author TEXT)',
        )
        // In the corpus with the same words (punctuation differs):
        ..execute('INSERT INTO favorites (quote, author) VALUES (?, ?)', [
          'We suffer more often in imagination than in reality',
          'Seneca',
        ])
        // Not in the corpus (a known misattribution):
        ..execute('INSERT INTO favorites (quote, author) VALUES (?, ?)', [
          'What we do now echoes in eternity.',
          'Marcus Aurelius',
        ]);
      db.close();
      final before = old.readAsBytesSync();

      final repo = UserRepository(openTestUserDatabase());
      addTearDown(repo.close);
      final n = await migrateLegacyFavorites(
        repository: repo,
        content: content,
        oldDatabase: old,
      );
      expect(n, 2);
      expect(await repo.watchFavoriteIds().first, ['sen-13-4-a']);
      final legacy = await repo.watchLegacyFavorites().first;
      expect(legacy.single.quote, 'What we do now echoes in eternity.');

      // Second run does nothing; the old file is unchanged.
      expect(
        await migrateLegacyFavorites(
          repository: repo,
          content: content,
          oldDatabase: old,
        ),
        0,
      );
      expect(old.readAsBytesSync(), before);
    },
  );

  test('no old database: marks done without importing', () async {
    final repo = UserRepository(openTestUserDatabase());
    addTearDown(repo.close);
    final n = await migrateLegacyFavorites(
      repository: repo,
      content: loadContentFromDisk(),
      oldDatabase: File('/nonexistent/favorites.db'),
    );
    expect(n, 0);
    expect(await repo.setting(legacyMigratedKey), isNotNull);
  });
}
