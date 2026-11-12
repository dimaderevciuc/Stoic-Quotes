/// All reads and writes of the user's own data go through here.
library;

import 'package:drift/drift.dart';

import 'user_database.dart';

export 'user_database.dart' show LegacyFavorite;

class UserRepository {
  UserRepository(this._db);

  final UserDatabase _db;

  // Favorites, newest first.
  Stream<List<String>> watchFavoriteIds() {
    final query = _db.select(_db.favorites)
      ..orderBy([(f) => OrderingTerm.desc(f.addedAt)]);
    return query.map((f) => f.quoteId).watch();
  }

  Future<void> addFavorite(String quoteId) => _db
      .into(_db.favorites)
      .insertOnConflictUpdate(
        FavoritesCompanion.insert(quoteId: quoteId, addedAt: DateTime.now()),
      );

  Future<void> removeFavorite(String quoteId) =>
      (_db.delete(_db.favorites)..where((f) => f.quoteId.equals(quoteId))).go();

  Future<bool> isFavorite(String quoteId) async =>
      await (_db.select(
        _db.favorites,
      )..where((f) => f.quoteId.equals(quoteId))).getSingleOrNull() !=
      null;

  Future<void> toggleFavorite(String quoteId) async => await isFavorite(quoteId)
      ? removeFavorite(quoteId)
      : addFavorite(quoteId);

  // Favorites kept from the first version of the app.
  Stream<List<LegacyFavorite>> watchLegacyFavorites() =>
      _db.select(_db.legacyFavorites).watch();

  Future<void> addLegacyFavorite(String quote, String author) => _db
      .into(_db.legacyFavorites)
      .insert(LegacyFavoritesCompanion.insert(quote: quote, author: author));

  Future<void> removeLegacyFavorite(int id) =>
      (_db.delete(_db.legacyFavorites)..where((f) => f.id.equals(id))).go();

  // Explore shuffle bag.
  Future<Set<String>> seenQuoteIds() async =>
      (await _db.select(_db.seenQuotes).get()).map((s) => s.quoteId).toSet();

  Future<void> markSeen(String quoteId) => _db
      .into(_db.seenQuotes)
      .insertOnConflictUpdate(SeenQuotesCompanion.insert(quoteId: quoteId));

  Future<void> clearSeen() => _db.delete(_db.seenQuotes).go();

  // Small settings.
  Future<String?> setting(String key) async => (await (_db.select(
    _db.settings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> close() => _db.close();
}
