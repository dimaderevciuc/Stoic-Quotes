// The user database on disk must be unreadable without the key.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:stoic_quotes/core/user/user_database.dart';
import 'package:stoic_quotes/core/user/user_repository.dart';

void main() {
  test('user.db is encrypted and opens again with the same key', () async {
    final dir = await Directory.systemTemp.createTemp('stoic');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/user.db');
    final key = 'ab' * 32;

    var repo = UserRepository(openUserDatabase(file, key));
    await repo.addFavorite('ma-4-3-a');
    await repo.close();

    // The plain SQLite header is missing: the file is not readable as is.
    final header = String.fromCharCodes(file.readAsBytesSync().take(15));
    expect(header, isNot('SQLite format 3'));
    final raw = sqlite3.open(file.path);
    expect(
      () => raw.select('SELECT * FROM favorites'),
      throwsA(isA<SqliteException>()),
    );
    raw.close();

    repo = UserRepository(openUserDatabase(file, key));
    expect(await repo.watchFavoriteIds().first, ['ma-4-3-a']);
    await repo.close();
  });
}
