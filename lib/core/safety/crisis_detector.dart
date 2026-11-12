/// Crisis detection: runs on the user's text before anything else.
///
/// Two rules, both tuned to flag rather than miss (pipeline safety.py):
/// 1. a keyword phrase such as "want to die" appears as whole words;
/// 2. the text's vector is close to one of the crisis example sentences.
/// A keyword hit is treated as certain; a similarity hit may be a false alarm,
/// so the crisis screen then also offers to continue.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../embedding/int8_matrix.dart';
import '../embedding/quote_index.dart';

enum CrisisLevel { none, possible, certain }

class CrisisDetector {
  CrisisDetector({
    required List<String> keywords,
    required this.examples,
    required this.threshold,
  }) : _keywords = [for (final k in keywords) ' ${normalize(k).trim()} '];

  factory CrisisDetector.fromAssets(String json, ByteData examples) {
    final config = jsonDecode(json) as Map<String, dynamic>;
    final matrix = Int8Matrix.fromBytes(examples);
    return CrisisDetector(
      keywords: [
        for (final k in config['keywords'] as List<dynamic>) k as String,
      ],
      examples: QuoteIndex(
        ids: [for (var i = 0; i < matrix.rows; i++) 'crisis-$i'],
        vectors: matrix,
      ),
      threshold: (config['similarity_threshold'] as num).toDouble(),
    );
  }

  final List<String> _keywords;
  final QuoteIndex examples;
  final double threshold;

  static final _notWord = RegExp(r"[^a-z0-9']+");
  static final _curly = {0x2019: "'", 0x2018: "'", 0x201C: '"', 0x201D: '"'};

  /// Same as `normalize` in pipeline safety.py: lowercase, straight quotes,
  /// every non word character a space, padded with one space on each side.
  static String normalize(String text) {
    final straight = StringBuffer();
    for (final cp in text.toLowerCase().runes) {
      straight.write(_curly[cp] ?? String.fromCharCode(cp));
    }
    final spaced = straight.toString().replaceAll(_notWord, ' ').trim();
    return ' $spaced ';
  }

  /// The matching keyword phrase, or null. Needs no model, so it runs instantly.
  String? keywordHit(String text) {
    final padded = normalize(text);
    for (final k in _keywords) {
      if (padded.contains(k)) return k.trim();
    }
    return null;
  }

  CrisisLevel check(String text, Float32List? vector) {
    if (keywordHit(text) != null) return CrisisLevel.certain;
    if (vector == null) return CrisisLevel.none;
    final best = examples.search(vector, k: 1).first.score;
    return best >= threshold ? CrisisLevel.possible : CrisisLevel.none;
  }
}
