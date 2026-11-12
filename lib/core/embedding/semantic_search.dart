/// Answers "which quotes fit this text?" from the exported embedding assets.
///
/// Parsing (tokenizer tables, quote vectors) is plain Dart and runs in tests;
/// only [TextEmbedder] needs the native ONNX Runtime.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'char_tables.dart';
import 'int8_matrix.dart';
import 'quote_index.dart';
import 'tokenizer.dart';

export 'quote_index.dart' show QuoteHit;

/// Turns token ids into a unit vector (the ONNX model in the app, fakes in tests).
abstract interface class TextEmbedder {
  Future<Float32List> embedIds(List<int> ids);
}

/// The raw asset contents, so the same parsing works with rootBundle in the app
/// and with plain files in tests.
class EmbeddingAssets {
  const EmbeddingAssets({
    required this.config,
    required this.vocab,
    required this.chars,
    required this.quotes,
  });

  static const dir = 'assets/embedding';

  final String config;
  final String vocab;
  final String chars;
  final ByteData quotes;
}

/// Everything except the model, parsed and checked.
class EmbeddingData {
  EmbeddingData._(this.tokenizer, this.index, this.onnxFile);

  factory EmbeddingData.parse(EmbeddingAssets assets) {
    final config = jsonDecode(assets.config) as Map<String, dynamic>;
    final specials = <String, int>{
      for (final e
          in (config['special_tokens'] as Map<String, dynamic>).entries)
        e.key: e.value as int,
    };
    final tokenizer = WordPieceTokenizer(
      vocab: const LineSplitter().convert(assets.vocab),
      tables: CharTables.fromJson(assets.chars),
      specialTokens: specials,
      clsId: config['cls_id'] as int,
      sepId: config['sep_id'] as int,
      unkId: config['unk_id'] as int,
      subwordPrefix: config['continuing_subword_prefix'] as String,
      maxInputCharsPerWord: config['max_input_chars_per_word'] as int,
      maxLength: config['max_length'] as int,
    );
    final index = QuoteIndex(
      ids: [
        for (final id in config['quote_ids'] as List<dynamic>) id as String,
      ],
      vectors: Int8Matrix.fromBytes(assets.quotes),
    );
    return EmbeddingData._(tokenizer, index, config['onnx_file'] as String);
  }

  final WordPieceTokenizer tokenizer;
  final QuoteIndex index;

  /// File name of the model inside [EmbeddingAssets.dir].
  final String onnxFile;

  int get dim => index.vectors.dim;
}

class SemanticSearch {
  SemanticSearch(this.data, this.embedder);

  final EmbeddingData data;
  final TextEmbedder embedder;

  Future<Float32List> embed(String text) =>
      embedder.embedIds(data.tokenizer.tokenize(text));

  Future<List<QuoteHit>> search(String text, {int k = 5}) async =>
      data.index.search(await embed(text), k: k);
}
