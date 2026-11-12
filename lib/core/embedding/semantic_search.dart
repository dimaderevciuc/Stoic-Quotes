/// Answers "which situation and quotes fit this text?" from the exported assets.
///
/// Parsing (tokenizer tables, vectors, situations) is plain Dart and runs in
/// tests; only [TextEmbedder] needs the native ONNX Runtime.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'char_tables.dart';
import 'int8_matrix.dart';
import 'quote_index.dart';
import 'situation.dart';
import 'tokenizer.dart';

export 'quote_index.dart' show QuoteHit;
export 'situation.dart';

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
    required this.situationVectors,
    required this.situations,
  });

  static const dir = 'assets/embedding';

  final String config;
  final String vocab;
  final String chars;
  final ByteData quotes;
  final ByteData situationVectors;
  final String situations;
}

/// Everything except the model, parsed and checked.
class EmbeddingData {
  EmbeddingData._({
    required this.tokenizer,
    required this.index,
    required this.situationIndex,
    required this.situations,
    required this.situationThreshold,
    required this.onnxFile,
  });

  factory EmbeddingData.parse(EmbeddingAssets assets) {
    final config = jsonDecode(assets.config) as Map<String, dynamic>;
    List<String> strings(String key) => [
      for (final v in config[key] as List<dynamic>) v as String,
    ];
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
      ids: strings('quote_ids'),
      vectors: Int8Matrix.fromBytes(assets.quotes),
    );
    final situationIndex = QuoteIndex(
      ids: strings('situation_ids'),
      vectors: Int8Matrix.fromBytes(assets.situationVectors),
    );
    final situations = <String, Situation>{
      for (final s in jsonDecode(assets.situations) as List<dynamic>)
        (s as Map<String, dynamic>)['id'] as String: Situation.fromJson(s),
    };
    // Every vector needs its content, and every hand-picked quote must exist.
    final quoteIds = index.ids.toSet();
    for (final id in situationIndex.ids) {
      final s = situations[id];
      if (s == null) throw FormatException('no content for situation $id');
      final unknown = s.quoteIds.where((q) => !quoteIds.contains(q));
      if (unknown.isNotEmpty) {
        throw FormatException('situation $id uses unknown quotes $unknown');
      }
    }
    if (situationIndex.vectors.dim != index.vectors.dim) {
      throw const FormatException('situation and quote vectors differ in size');
    }
    return EmbeddingData._(
      tokenizer: tokenizer,
      index: index,
      situationIndex: situationIndex,
      situations: situations,
      situationThreshold: (config['situation_threshold'] as num).toDouble(),
      onnxFile: config['onnx_file'] as String,
    );
  }

  final WordPieceTokenizer tokenizer;
  final QuoteIndex index;
  final QuoteIndex situationIndex;
  final Map<String, Situation> situations;

  /// Minimum similarity for showing a situation (tuned in the pipeline).
  final double situationThreshold;

  /// File name of the model inside [EmbeddingAssets.dir].
  final String onnxFile;

  int get dim => index.vectors.dim;

  /// Same logic as `combined_ranking` in pipeline situations.py: if the best
  /// situation is close enough, its quotes come first, then the plain search.
  SearchResult rank(Float32List query, {int k = 5}) {
    final best = situationIndex.search(query, k: 1).first;
    final plain = index.search(query, k: index.ids.length);
    if (best.score < situationThreshold) {
      return SearchResult(null, best.score, plain.take(k).toList());
    }
    final situation = situations[best.id]!;
    final byId = {for (final h in plain) h.id: h};
    final picked = [for (final id in situation.quoteIds) byId[id]!];
    final rest = plain.where((h) => !situation.quoteIds.contains(h.id));
    return SearchResult(
      situation,
      best.score,
      [...picked, ...rest].take(k).toList(),
    );
  }
}

class SearchResult {
  const SearchResult(this.situation, this.situationScore, this.quotes);

  /// The matched situation, or null when none is close enough.
  final Situation? situation;

  /// Similarity of the best situation, shown or not (useful for debugging).
  final double situationScore;

  final List<QuoteHit> quotes;
}

class SemanticSearch {
  SemanticSearch(this.data, this.embedder);

  final EmbeddingData data;
  final TextEmbedder embedder;

  Future<Float32List> embed(String text) =>
      embedder.embedIds(data.tokenizer.tokenize(text));

  /// Plain quote search, without situations.
  Future<List<QuoteHit>> searchQuotes(String text, {int k = 5}) async =>
      data.index.search(await embed(text), k: k);

  /// What the main screen shows: a situation if one fits, and the quotes.
  Future<SearchResult> search(String text, {int k = 5}) async =>
      data.rank(await embed(text), k: k);
}
