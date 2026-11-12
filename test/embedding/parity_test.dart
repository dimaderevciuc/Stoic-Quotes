// Host side of the parity check: the Dart tokenizer and search must match Python.
// The model itself needs the native ONNX Runtime, so it is checked by
// integration_test/embedding_parity_test.dart (flutter test integration_test -d linux).
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/core/embedding/pooling.dart';
import 'package:stoic_quotes/core/embedding/semantic_search.dart';

import 'parity_fixture.dart';

void main() {
  final data = EmbeddingData.parse(loadAssetsFromDisk());
  final cases = loadParityCases();

  test('has the 30 reference sentences', () => expect(cases, hasLength(30)));

  for (final (i, c) in cases.indexed) {
    test('tokens match, case $i: ${c.label}', () {
      expect(data.tokenizer.tokenize(c.text), c.tokenIds);
    });

    test('search on the Python query vector matches, case $i: ${c.label}', () {
      final hits = data.index.search(c.query);
      expect([for (final h in hits) h.id], c.top5Ids);
      for (final (j, score) in c.top5Scores.indexed) {
        expect(hits[j].score, closeTo(score, 1e-4));
      }
    });
  }

  for (final (i, c) in cases.indexed) {
    test('situations match Python, case $i: ${c.label}', () {
      final hits = data.situationIndex.search(c.query, k: 3);
      expect([for (final h in hits) h.id], c.top3Situations);
    });
  }

  test('combined ranking puts the situation quotes first', () {
    final c = cases.first; // a job rejection: should match a situation
    final result = data.rank(c.query);
    expect(result.situation, isNotNull);
    expect(result.situation!.id, c.top3Situations.first);
    final picked = result.situation!.quoteIds;
    expect([
      for (final h in result.quotes.take(picked.length)) h.id,
    ], picked.take(result.quotes.length).toList());
  });

  test('off topic text falls back to plain quotes', () {
    final c = cases.firstWhere((c) => c.text.startsWith('12345'));
    final result = data.rank(c.query);
    expect(result.situation, isNull);
    expect(
      [for (final h in result.quotes) h.id],
      [for (final h in data.index.search(c.query)) h.id],
    );
  });

  test('every situation is loaded with content', () {
    expect(data.situations, hasLength(data.situationIndex.ids.length));
    expect(data.situations.length, 157);
  });

  test('mean pooling and normalization', () {
    // Two tokens of dim 2: mean (2, 1) -> unit vector (2, 1) / sqrt(5).
    final v = meanPoolNormalize([1, 0, 3, 2], 2, 2);
    expect(v[0], closeTo(2 / math.sqrt(5), 1e-6));
    expect(v[1], closeTo(1 / math.sqrt(5), 1e-6));
    expect(meanPoolNormalize([0, 0], 1, 2), [0, 0]);
  });

  test('the index search is fast', () {
    final query = cases.first.query;
    for (var i = 0; i < 20; i++) {
      data.index.search(query); // warm up the JIT
    }
    final watch = Stopwatch()..start();
    const runs = 200;
    for (var i = 0; i < runs; i++) {
      data.index.search(query);
    }
    final ms = watch.elapsedMicroseconds / runs / 1000;
    // ignore: avoid_print
    print('index search: ${ms.toStringAsFixed(3)} ms on this machine');
    expect(ms, lessThan(16));
  });
}
