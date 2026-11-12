import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final content = loadContentFromDisk();

  test('all exported quotes, situations and sources load', () {
    expect(content.quotes.length, 593);
    expect(content.situations.length, 157);
    expect(content.sources.length, 5);
  });

  test('every situation quote exists and has an application', () {
    for (final s in content.situations.values) {
      expect(s.quoteIds, isNotEmpty);
      for (final id in s.quoteIds) {
        expect(content.quote(id), isNotNull, reason: '${s.id} -> $id');
        expect(s.applications[id], isNotNull);
      }
    }
  });

  test('source line has no dashes and names the translator', () {
    final q = content.quote('ma-4-3-a')!;
    expect(q.sourceLine, 'Meditations 4.3 · tr. George Long, 1862');
    for (final q in content.quotes) {
      expect(q.explanation.contains(String.fromCharCode(0x2014)), isFalse);
      expect(q.explanation.contains(String.fromCharCode(0x2013)), isFalse);
    }
  });
}
