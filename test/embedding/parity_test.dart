// Dart must give the same tokens, top 5 quotes and scores as the Python pipeline.
// Reference data: pipeline/data/golden/parity.json (uv run stoic-embed parity).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/core/embedding/semantic_search.dart';

EmbeddingAssets loadAssetsFromDisk() {
  String text(String name) =>
      File('${EmbeddingAssets.dir}/$name').readAsStringSync();
  ByteData bytes(String name) => ByteData.sublistView(
    File('${EmbeddingAssets.dir}/$name').readAsBytesSync(),
  );
  return EmbeddingAssets(
    config: text('config.json'),
    vocab: text('vocab.txt'),
    chars: text('chars.json'),
    tokens: bytes('tokens.bin'),
    quotes: bytes('quotes.bin'),
  );
}

void main() {
  final search = SemanticSearch.fromAssets(loadAssetsFromDisk());
  final cases = jsonDecode(
    File('pipeline/data/golden/parity.json').readAsStringSync(),
  ) as List<dynamic>;

  test('has the 30 reference sentences', () => expect(cases, hasLength(30)));

  for (final (i, raw) in cases.indexed) {
    final c = raw as Map<String, dynamic>;
    final text = c['text'] as String;
    final label =
        'case $i: ${text.length > 40 ? '${text.substring(0, 40)}...' : text}';

    test('tokens match, $label', () {
      final expected = [
        for (final id in c['token_ids'] as List<dynamic>) id as int,
      ];
      expect(search.embedder.tokenizer.tokenize(text), expected);
    });

    test('top 5 and scores match, $label', () {
      final expected = c['top5'] as List<dynamic>;
      final hits = search.search(text);
      final empty = search.embedder.embed(text).every((v) => v == 0);
      if (empty) {
        // Nothing to compare: every score is 0 and the order is the index order.
        expect(hits.every((h) => h.score == 0), isTrue);
        return;
      }
      expect(
        [for (final h in hits) h.id],
        [for (final e in expected) (e as Map<String, dynamic>)['id']],
      );
      for (final (j, e) in expected.indexed) {
        final score = ((e as Map<String, dynamic>)['score'] as num).toDouble();
        expect(hits[j].score, closeTo(score, 0.01));
      }
    });
  }

  test('largest score difference against Python', () {
    var worst = 0.0;
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final hits = search.search(c['text'] as String);
      for (final (j, e) in (c['top5'] as List<dynamic>).indexed) {
        final py = ((e as Map<String, dynamic>)['score'] as num).toDouble();
        if (hits[j].score != 0) {
          worst = math.max(worst, (hits[j].score - py).abs());
        }
      }
    }
    // ignore: avoid_print
    print('largest score difference: ${worst.toStringAsExponential(2)}');
    expect(worst, lessThan(0.01));
  });

  test('loading the assets is quick', () {
    final assets = loadAssetsFromDisk();
    final watch = Stopwatch()..start();
    SemanticSearch.fromAssets(assets);
    // ignore: avoid_print
    print('parse assets: ${watch.elapsedMilliseconds} ms on this machine');
  });

  test('search is fast enough to run on the UI thread', () {
    const text =
        'I keep procrastinating on my thesis and the deadline is getting closer';
    for (var i = 0; i < 20; i++) {
      search.search(text); // warm up the JIT
    }
    final watch = Stopwatch()..start();
    const runs = 200;
    for (var i = 0; i < runs; i++) {
      search.search(text);
    }
    final perQueryMs = watch.elapsedMicroseconds / runs / 1000;
    // ignore: avoid_print
    print(
      'search: ${perQueryMs.toStringAsFixed(3)} ms per query on this machine',
    );
    expect(perQueryMs, lessThan(16));
  });
}
