/// Encrypted on-device store for the user's own data: favorites, seen quotes,
/// small settings. Nothing the user types into the app is ever stored here.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

part 'user_database.g.dart';

class Favorites extends Table {
  TextColumn get quoteId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {quoteId};
}

/// Favorites from the first version of the app whose text is not in the new,
/// sourced corpus. Kept so nothing the user saved is lost.
class LegacyFavorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get quote => text()();
  TextColumn get author => text()();
}

/// The Explore shuffle bag: quotes already shown in the current round.
class SeenQuotes extends Table {
  TextColumn get quoteId => text()();

  @override
  Set<Column<Object>> get primaryKey => {quoteId};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [Favorites, LegacyFavorites, SeenQuotes, Settings])
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// Opens (or creates) the encrypted database at [file] with a 32 byte [hexKey].
///
/// Refuses to run without encryption support, so user data is never written in
/// plain text by accident.
UserDatabase openUserDatabase(File file, String hexKey) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hexKey)) {
    throw ArgumentError('the key must be 64 lowercase hex characters');
  }
  return UserDatabase(
    NativeDatabase.createInBackground(file, setup: (db) => _unlock(db, hexKey)),
  );
}

/// In-memory database for tests. Memory databases cannot be keyed, so this only
/// checks that the encrypting build is loaded (encryption_test covers the key).
UserDatabase openTestUserDatabase() =>
    UserDatabase(NativeDatabase.memory(setup: _requireCipher));

void _requireCipher(Database db) {
  // SQLite3MultipleCiphers answers this pragma; plain SQLite returns nothing.
  if (db.select('PRAGMA cipher').isEmpty) {
    throw StateError(
      'SQLite was built without encryption (sqlite3mc expected)',
    );
  }
}

void _unlock(Database db, String hexKey) {
  _requireCipher(db);
  db.execute("PRAGMA hexkey = '$hexKey'");
  // Fails here, not later, if the key is wrong.
  db.select('SELECT count(*) FROM sqlite_master');
}
