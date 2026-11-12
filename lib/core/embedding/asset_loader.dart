/// Loads the embedding assets from the app bundle.
library;

import 'dart:isolate';

import 'package:flutter/services.dart';

import 'semantic_search.dart';

/// Reads the assets, then parses them on a background isolate so the about
/// 8 MB matrix and the character tables never block a frame. Call once at startup.
Future<SemanticSearch> loadSemanticSearch([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  const dir = EmbeddingAssets.dir;
  final assets = EmbeddingAssets(
    config: await b.loadString('$dir/config.json'),
    vocab: await b.loadString('$dir/vocab.txt'),
    chars: await b.loadString('$dir/chars.json'),
    tokens: await b.load('$dir/tokens.bin'),
    quotes: await b.load('$dir/quotes.bin'),
  );
  return Isolate.run(() => SemanticSearch.fromAssets(assets));
}
