/// Loads the embedding assets and the ONNX model from the app bundle.
library;

import 'dart:isolate';

import 'package:flutter/services.dart';

import 'onnx_embedder.dart';
import 'semantic_search.dart';

/// Call once at startup. The tables are parsed on a background isolate so they
/// never block a frame; the model session is created by the native plugin.
Future<SemanticSearch> loadSemanticSearch([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  const dir = EmbeddingAssets.dir;
  final assets = EmbeddingAssets(
    config: await b.loadString('$dir/config.json'),
    vocab: await b.loadString('$dir/vocab.txt'),
    chars: await b.loadString('$dir/chars.json'),
    quotes: await b.load('$dir/quotes.bin'),
    situationVectors: await b.load('$dir/situations.bin'),
    situations: await b.loadString('$dir/situations.json'),
  );
  final data = await Isolate.run(() => EmbeddingData.parse(assets));
  final embedder = await OnnxEmbedder.fromAsset(
    '$dir/${data.onnxFile}',
    dim: data.dim,
  );
  return SemanticSearch(data, embedder);
}
