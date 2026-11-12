/// The user database key: 32 random bytes, created once, kept in the Android
/// Keystore through flutter_secure_storage. It never leaves the device.
library;

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyName = 'user_db_key_v1';

Future<String> loadOrCreateDatabaseKey([FlutterSecureStorage? storage]) async {
  final store = storage ?? const FlutterSecureStorage();
  final existing = await store.read(key: _keyName);
  if (existing != null) return existing;
  final random = Random.secure();
  final key = [
    for (var i = 0; i < 32; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  await store.write(key: _keyName, value: key);
  return key;
}
