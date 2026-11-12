/// A copy of the Hugging Face BERT WordPiece tokenizer as Model2Vec uses it.
///
/// Steps, each matching the Python side (verified by test/embedding tests):
/// 1. Cut the input to maxLength * medianTokenLength code points (model2vec encode).
/// 2. Normalize every code point with the exported tables (BertNormalizer).
/// 3. Split on whitespace and isolate punctuation (BertPreTokenizer).
/// 4. Greedy longest match WordPiece; a word that cannot be split becomes [UNK].
/// 5. Keep the first maxLength tokens, then drop [UNK] (model2vec tokenize).
/// No [CLS] or [SEP] are added: Model2Vec encodes without special tokens.
library;

import 'char_tables.dart';

class WordPieceTokenizer {
  WordPieceTokenizer({
    required List<String> vocab,
    required this.tables,
    required this.unkId,
    required this.subwordPrefix,
    required this.maxInputCharsPerWord,
    required this.maxLength,
    required this.medianTokenLength,
  }) : _vocab = {for (var i = 0; i < vocab.length; i++) vocab[i]: i};

  final Map<String, int> _vocab;
  final CharTables tables;
  final int unkId;
  final String subwordPrefix;
  final int maxInputCharsPerWord;

  /// Null means no truncation (some models disable it).
  final int? maxLength;
  final int medianTokenLength;

  List<int> tokenize(String text) {
    final ids = <int>[];
    for (final word in preTokenize(normalize(_truncateChars(text)))) {
      ids.addAll(_wordPiece(word));
      if (maxLength != null && ids.length >= maxLength!) break;
    }
    final kept = maxLength == null || ids.length <= maxLength!
        ? ids
        : ids.sublist(0, maxLength);
    return [
      for (final id in kept)
        if (id != unkId) id,
    ];
  }

  String _truncateChars(String text) {
    if (maxLength == null) return text;
    final limit = maxLength! * medianTokenLength;
    final runes = text.runes;
    return runes.length <= limit
        ? text
        : String.fromCharCodes(runes.take(limit));
  }

  String normalize(String text) {
    final out = StringBuffer();
    for (final cp in text.runes) {
      if (tables.deleted.contains(cp)) continue;
      final mapped = tables.mapped[cp];
      if (mapped != null) {
        out.write(mapped);
      } else if (tables.spaced.contains(cp)) {
        out
          ..write(' ')
          ..writeCharCode(cp)
          ..write(' ');
      } else {
        out.writeCharCode(cp);
      }
    }
    return out.toString();
  }

  /// Words as lists of code points.
  List<List<int>> preTokenize(String text) {
    final words = <List<int>>[];
    var current = <int>[];
    void flush() {
      if (current.isNotEmpty) words.add(current);
      current = <int>[];
    }

    for (final cp in text.runes) {
      if (tables.whitespace.contains(cp)) {
        flush();
      } else if (tables.punctuation.contains(cp)) {
        flush();
        words.add([cp]);
      } else {
        current.add(cp);
      }
    }
    flush();
    return words;
  }

  List<int> _wordPiece(List<int> word) {
    if (word.length > maxInputCharsPerWord) return [unkId];
    final pieces = <int>[];
    var start = 0;
    while (start < word.length) {
      int? found;
      var end = word.length;
      while (start < end) {
        var piece = String.fromCharCodes(word.sublist(start, end));
        if (start > 0) piece = '$subwordPrefix$piece';
        found = _vocab[piece];
        if (found != null) break;
        end--;
      }
      if (found == null) return [unkId]; // the whole word is unknown, as in HF
      pieces.add(found);
      start = end;
    }
    return pieces;
  }
}
