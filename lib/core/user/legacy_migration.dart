/// One time import of favorites from the first app version (sqflite favorites.db).
///
/// The old file is only read, never changed or deleted. Favorites whose text is
/// in the new corpus become normal favorites; the others are kept as legacy
/// favorites so nothing the user saved is lost.
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../content/content_repository.dart';
import 'user_repository.dart';

const legacyMigratedKey = 'legacy_favorites_migrated';

/// Letters and digits only, lowercase: tolerant of punctuation and quote marks.
String _plain(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// Returns how many old favorites were imported (0 if there was nothing to do).
Future<int> migrateLegacyFavorites({
  required UserRepository repository,
  required Content content,
  required File oldDatabase,
}) async {
  if (await repository.setting(legacyMigratedKey) != null) return 0;
  var imported = 0;
  if (oldDatabase.existsSync()) {
    final rows = _readOld(oldDatabase);
    final byText = {for (final q in content.quotes) _plain(q.text): q.id};
    for (final (quote, author) in rows) {
      final plain = _plain(quote);
      final match =
          byText[plain] ??
          byText.entries
              .where(
                (e) =>
                    plain.length > 30 &&
                    (e.key.contains(plain) || plain.contains(e.key)),
              )
              .map((e) => e.value)
              .firstOrNull;
      if (match != null) {
        await repository.addFavorite(match);
      } else {
        await repository.addLegacyFavorite(quote, author);
      }
      imported++;
    }
  }
  await repository.setSetting(
    legacyMigratedKey,
    DateTime.now().toIso8601String(),
  );
  return imported;
}

List<(String, String)> _readOld(File file) {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return [
      for (final row in db.select('SELECT quote, author FROM favorites'))
        ((row['quote'] as String?) ?? '', (row['author'] as String?) ?? ''),
    ].where((r) => r.$1.trim().isNotEmpty).toList();
  } on SqliteException {
    return const []; // not the expected table: nothing to import
  } finally {
    db.close();
  }
}
