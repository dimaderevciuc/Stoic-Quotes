/// Character tables exported by the pipeline (`assets/embedding/chars.json`).
///
/// Dart has no Unicode normalization or category lookup, so the pipeline asks the
/// real Hugging Face BertNormalizer and BertPreTokenizer what they do to every code
/// point and exports the answers. Lookups are binary searches over sorted ranges.
library;

import 'dart:convert';

class CodePointRanges {
  CodePointRanges(List<List<int>> ranges)
    : _starts = [for (final r in ranges) r[0]],
      _ends = [for (final r in ranges) r[1]];

  final List<int> _starts;
  final List<int> _ends; // inclusive

  bool contains(int cp) {
    var lo = 0;
    var hi = _starts.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (cp < _starts[mid]) {
        hi = mid - 1;
      } else if (cp > _ends[mid]) {
        lo = mid + 1;
      } else {
        return true;
      }
    }
    return false;
  }
}

class CharTables {
  CharTables({
    required this.deleted,
    required this.spaced,
    required this.mapped,
    required this.punctuation,
    required this.whitespace,
  });

  factory CharTables.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    CodePointRanges ranges(String key) => CodePointRanges([
      for (final r in json[key] as List<dynamic>)
        [for (final v in r as List<dynamic>) v as int],
    ]);
    final mapped = <int, String>{
      for (final e in (json['mapped'] as Map<String, dynamic>).entries)
        int.parse(e.key): e.value as String,
    };
    return CharTables(
      deleted: ranges('deleted'),
      spaced: ranges('spaced'),
      mapped: mapped,
      punctuation: ranges('punctuation'),
      whitespace: ranges('whitespace'),
    );
  }

  /// Removed by the normalizer: control, format and unassigned code points, accents.
  final CodePointRanges deleted;

  /// CJK ideographs, which get a space on each side so each becomes its own word.
  final CodePointRanges spaced;

  /// Everything else the normalizer changes (lowercase, accent stripped, decomposed).
  final Map<int, String> mapped;

  final CodePointRanges punctuation;
  final CodePointRanges whitespace;
}
