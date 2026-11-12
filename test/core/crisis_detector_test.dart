import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/core/safety/crisis_detector.dart';

CrisisDetector loadDetector() => CrisisDetector.fromAssets(
  File('assets/safety/crisis.json').readAsStringSync(),
  ByteData.sublistView(File('assets/safety/crisis.bin').readAsBytesSync()),
);

void main() {
  final detector = loadDetector();
  final cases = jsonDecode(
    File('pipeline/data/golden/safety_parity.json').readAsStringSync(),
  ) as List<dynamic>;

  test('normalize and keyword hits match Python on every test sentence', () {
    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final text = c['text'] as String;
      expect(CrisisDetector.normalize(text), c['normalized'], reason: text);
      expect(detector.keywordHit(text), c['keyword'], reason: text);
    }
  });

  test('clear phrases are certain without any model', () {
    for (final text in [
      'I want to die',
      'thinking about suicide',
      'I keep hurting myself',
      "I'm not safe at home",
      'I wish I were dead.',
    ]) {
      expect(detector.check(text, null), CrisisLevel.certain, reason: text);
    }
  });

  test('ordinary sentences are not flagged by keywords', () {
    for (final text in [
      'I keep procrastinating',
      'my boss criticized me',
      'the curtains were draped nicely',
      'I am afraid of failing my exam',
    ]) {
      expect(detector.check(text, null), CrisisLevel.none, reason: text);
    }
  });

  test('similarity to a crisis example gives a possible crisis', () {
    final dim = detector.examples.vectors.dim;
    // Rebuild example 0 as a unit vector: identical text, similarity 1.
    final row = Float32List(dim);
    final m = detector.examples.vectors;
    var norm = 0.0;
    for (var j = 0; j < dim; j++) {
      row[j] = m.data[j] * m.scales[0];
      norm += row[j] * row[j];
    }
    for (var j = 0; j < dim; j++) {
      row[j] /= norm == 0 ? 1 : math.sqrt(norm);
    }
    expect(detector.check('words without keywords', row), CrisisLevel.possible);
    expect(
      detector.check('words without keywords', Float32List(dim)),
      CrisisLevel.none,
    );
  });

  test('curly apostrophes match straight ones', () {
    final curly = 'I${String.fromCharCode(0x2019)}m not safe';
    expect(detector.keywordHit(curly), "i'm not safe");
  });
}
