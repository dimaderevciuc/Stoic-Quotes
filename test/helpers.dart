// Shared test helpers: real content from the exported assets, fakes for the
// parts that need native code (the ONNX model).
import 'dart:io';

import 'package:stoic_quotes/core/content/content_repository.dart';
import 'package:stoic_quotes/core/content/quote.dart';
import 'package:stoic_quotes/core/embedding/situation.dart';
import 'package:stoic_quotes/core/reflection_service.dart';
import 'package:stoic_quotes/core/safety/crisis_detector.dart';

Content loadContentFromDisk() => Content.fromJson(
  quotesJson: File('assets/content/quotes.json').readAsStringSync(),
  situationsJson: File('assets/embedding/situations.json').readAsStringSync(),
  sourcesJson: File('assets/content/sources.json').readAsStringSync(),
);

/// Answers like the real service, without the model: a fixed situation for
/// procrastination, a crisis for "crisis", "maybe crisis" for a possible one,
/// and plain quotes otherwise. Records the calls so tests can check them.
class FakeReflectionFinder implements ReflectionFinder {
  FakeReflectionFinder(this.content);

  final Content content;
  final calls = <(String, bool)>[];

  @override
  Future<Reflection> reflect(
    String text, {
    bool acceptedPossibleCrisis = false,
  }) async {
    calls.add((text, acceptedPossibleCrisis));
    if (text.contains('maybe crisis')) {
      if (!acceptedPossibleCrisis) {
        return const CrisisReflection(CrisisLevel.possible);
      }
    } else if (text.contains('crisis')) {
      return const CrisisReflection(CrisisLevel.certain);
    }
    if (text.toLowerCase().contains('procrastinat')) {
      final Situation s = content.situations['procrastination']!;
      return FoundReflection(
        situation: s,
        quotes: [for (final id in s.quoteIds) content.quote(id)!],
      );
    }
    final List<Quote> some = content.quotes.take(3).toList();
    return FoundReflection(situation: null, quotes: some);
  }
}
