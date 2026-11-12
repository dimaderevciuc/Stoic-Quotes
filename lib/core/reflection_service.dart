/// Turns what the user wrote into a reflection: crisis check first, then the
/// matched situation (if any) and quotes. The text is never stored or logged.
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'content/content_repository.dart';
import 'content/quote.dart';
import 'embedding/asset_loader.dart';
import 'embedding/semantic_search.dart';
import 'safety/crisis_detector.dart';

sealed class Reflection {
  const Reflection();
}

/// Show the crisis screen instead of any quotes.
class CrisisReflection extends Reflection {
  const CrisisReflection(this.level);

  final CrisisLevel level;
}

class FoundReflection extends Reflection {
  const FoundReflection({required this.situation, required this.quotes});

  /// The matched situation, or null when none fits well enough.
  final Situation? situation;
  final List<Quote> quotes;
}

abstract interface class ReflectionFinder {
  /// [acceptedPossibleCrisis]: the user saw the crisis screen after a
  /// similarity (not keyword) match and chose to continue.
  Future<Reflection> reflect(
    String text, {
    bool acceptedPossibleCrisis = false,
  });
}

class ReflectionService implements ReflectionFinder {
  ReflectionService({
    required this.search,
    required this.detector,
    required this.content,
  });

  final SemanticSearch search;
  final CrisisDetector detector;
  final Content content;

  static const resultCount = 5;

  @override
  Future<Reflection> reflect(
    String text, {
    bool acceptedPossibleCrisis = false,
  }) async {
    // Keywords need no model, so a clear crisis is answered immediately.
    if (detector.keywordHit(text) != null) {
      return const CrisisReflection(CrisisLevel.certain);
    }
    final Float32List vector = await search.embed(text);
    final level = detector.check(text, vector);
    if (level == CrisisLevel.possible && !acceptedPossibleCrisis) {
      return const CrisisReflection(CrisisLevel.possible);
    }
    final result = search.data.rank(vector, k: resultCount);
    return FoundReflection(
      situation: result.situation,
      quotes: [
        for (final hit in result.quotes)
          ?content.quote(hit.id),
      ],
    );
  }
}

Future<ReflectionService> loadReflectionService(
  Content content, [
  AssetBundle? bundle,
]) async {
  final b = bundle ?? rootBundle;
  final search = await loadSemanticSearch(b);
  final crisisJson = await b.loadString('assets/safety/crisis.json');
  final crisisBin = await b.load('assets/safety/crisis.bin');
  final detector = await Isolate.run(
    () => CrisisDetector.fromAssets(crisisJson, crisisBin),
  );
  return ReflectionService(
    search: search,
    detector: detector,
    content: content,
  );
}
