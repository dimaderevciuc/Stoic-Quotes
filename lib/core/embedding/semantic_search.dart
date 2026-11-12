/// Loads the exported embedding assets and answers "which quotes fit this text?".
library;

import 'dart:convert';
import 'dart:typed_data';

import 'char_tables.dart';
import 'embedder.dart';
import 'int8_matrix.dart';
import 'quote_index.dart';
import 'tokenizer.dart';

export 'quote_index.dart' show QuoteHit;

/// The raw asset contents, so the same code works with rootBundle in the app and
/// with plain files in tests.
class EmbeddingAssets {
  const EmbeddingAssets({
    required this.config,
    required this.vocab,
    required this.chars,
    required this.tokens,
    required this.quotes,
  });

  static const dir = 'assets/embedding';

  final String config;
  final String vocab;
  final String chars;
  final ByteData tokens;
  final ByteData quotes;
}

class SemanticSearch {
  SemanticSearch._(this.embedder, this.index);

  factory SemanticSearch.fromAssets(EmbeddingAssets assets) {
    final config = jsonDecode(assets.config) as Map<String, dynamic>;
    final vocab = const LineSplitter().convert(assets.vocab);
    final tokenizer = WordPieceTokenizer(
      vocab: vocab,
      tables: CharTables.fromJson(assets.chars),
      unkId: config['unk_id'] as int,
      subwordPrefix: config['continuing_subword_prefix'] as String,
      maxInputCharsPerWord: config['max_input_chars_per_word'] as int,
      maxLength: config['max_length'] as int?,
      medianTokenLength: config['median_token_length'] as int,
    );
    final tokens = Int8Matrix.fromBytes(assets.tokens);
    if (tokens.rows != vocab.length) {
      throw FormatException(
        '${vocab.length} tokens in vocab, ${tokens.rows} rows in matrix',
      );
    }
    final index = QuoteIndex(
      ids: [
        for (final id in config['quote_ids'] as List<dynamic>) id as String,
      ],
      vectors: Int8Matrix.fromBytes(assets.quotes),
    );
    if (index.vectors.dim != tokens.dim) {
      throw const FormatException(
        'quote vectors and token vectors differ in size',
      );
    }
    return SemanticSearch._(
      StaticEmbedder(tokenizer: tokenizer, tokens: tokens),
      index,
    );
  }

  final StaticEmbedder embedder;
  final QuoteIndex index;

  List<QuoteHit> search(String text, {int k = 5}) =>
      index.search(embedder.embed(text), k: k);
}
