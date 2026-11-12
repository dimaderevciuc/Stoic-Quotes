// Full parity check with the real model: Dart tokenizer + ONNX Runtime + pooling
// + search must give Python's top 5 and scores for the 30 reference sentences.
// Run on this PC: flutter test integration_test -d linux
// (reads files relative to the repo root, so run it from there).
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stoic_quotes/core/embedding/asset_loader.dart';

import '../test/embedding/parity_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dart and ONNX Runtime match Python', (tester) async {
    final loadWatch = Stopwatch()..start();
    final search = await loadSemanticSearch();
    final loadMs = loadWatch.elapsedMilliseconds;
    final cases = loadParityCases();
    expect(cases, hasLength(30));

    var worst = 0.0;
    var sameTop5 = 0;
    final times = <int>[];
    for (final c in cases) {
      final watch = Stopwatch()..start();
      final hits = await search.searchQuotes(c.text);
      times.add(watch.elapsedMicroseconds);
      final ids = [for (final h in hits) h.id];
      if (_listEquals(ids, c.top5Ids)) sameTop5++;
      // Compare every Python top 5 quote with Dart's score for the same quote,
      // which also catches a swap of two near tied quotes.
      final query = await search.embed(c.text);
      final all = search.data.index.search(
        query,
        k: search.data.index.ids.length,
      );
      final dartScore = {for (final h in all) h.id: h.score};
      for (final (j, id) in c.top5Ids.indexed) {
        worst = math.max(worst, (dartScore[id]! - c.top5Scores[j]).abs());
      }
    }
    times.sort();
    // ignore: avoid_print
    print(
      'parity: $sameTop5/30 identical top 5, largest score difference '
      '${worst.toStringAsExponential(2)}, load $loadMs ms, '
      'search median ${(times[times.length ~/ 2] / 1000).toStringAsFixed(1)} ms, '
      'max ${(times.last / 1000).toStringAsFixed(1)} ms',
    );
    expect(sameTop5, 30);
    expect(worst, lessThan(0.01));
  });
}

bool _listEquals(List<String> a, List<String> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);
