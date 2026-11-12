/// A copy of the Hugging Face BERT WordPiece tokenizer used by the embedding model.
///
/// Steps, each matching `tokenizers` in Python (verified by test/embedding tests):
/// 1. Split out special token strings such as "[CLS]", matched case sensitive on
///    the raw text (they are "added tokens" with normalized: false).
/// 2. Normalize every code point with the exported tables (BertNormalizer).
/// 3. Split on whitespace and isolate punctuation (BertPreTokenizer).
/// 4. Greedy longest match WordPiece; a word that cannot be split becomes [UNK].
/// 5. Keep maxLength - 2 tokens and wrap them in [CLS] ... [SEP].
library;

import 'char_tables.dart';

class WordPieceTokenizer {
  WordPieceTokenizer({
    required List<String> vocab,
    required this.tables,
    required Map<String, int> specialTokens,
    required this.clsId,
    required this.sepId,
    required this.unkId,
    required this.subwordPrefix,
    required this.maxInputCharsPerWord,
    required this.maxLength,
  }) : _vocab = {for (var i = 0; i < vocab.length; i++) vocab[i]: i},
       // Longest first, so a longer special token wins over a prefix of it.
       _specials = specialTokens.entries.toList()
         ..sort((a, b) => b.key.length.compareTo(a.key.length));

  final Map<String, int> _vocab;
  final List<MapEntry<String, int>> _specials;
  final CharTables tables;
  final int clsId;
  final int sepId;
  final int unkId;
  final String subwordPrefix;
  final int maxInputCharsPerWord;

  /// Total length including [CLS] and [SEP].
  final int maxLength;

  List<int> tokenize(String text) {
    final budget = maxLength - 2;
    final ids = <int>[];
    for (final segment in _splitSpecial(text)) {
      if (segment.specialId != null) {
        ids.add(segment.specialId!);
      } else {
        for (final word in preTokenize(normalize(segment.text))) {
          ids.addAll(_wordPiece(word));
          if (ids.length >= budget) break;
        }
      }
      if (ids.length >= budget) break;
    }
    return [
      clsId,
      ...ids.length > budget ? ids.sublist(0, budget) : ids,
      sepId,
    ];
  }

  List<_Segment> _splitSpecial(String text) {
    final segments = <_Segment>[];
    var plainStart = 0;
    var i = 0;
    while (i < text.length) {
      MapEntry<String, int>? match;
      for (final special in _specials) {
        if (text.startsWith(special.key, i)) {
          match = special;
          break;
        }
      }
      if (match == null) {
        i++;
        continue;
      }
      if (i > plainStart) segments.add(_Segment(text.substring(plainStart, i)));
      segments.add(_Segment('', match.value));
      i += match.key.length;
      plainStart = i;
    }
    if (plainStart < text.length) {
      segments.add(_Segment(text.substring(plainStart)));
    }
    return segments;
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

class _Segment {
  const _Segment(this.text, [this.specialId]);

  final String text;
  final int? specialId;
}
