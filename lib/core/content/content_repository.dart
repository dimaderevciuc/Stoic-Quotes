/// Read-only app content (quotes, situations, credits), loaded once from assets.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../embedding/situation.dart';
import 'quote.dart';

class Content {
  Content({
    required List<Quote> quotes,
    required this.situations,
    required this.sources,
  }) : quotes = List.unmodifiable(quotes),
       _byId = {for (final q in quotes) q.id: q};

  /// Parses the JSON exported by the pipeline (stoic-export, stoic-embed export).
  factory Content.fromJson({
    required String quotesJson,
    required String situationsJson,
    required String sourcesJson,
  }) {
    final quotes = [
      for (final q in jsonDecode(quotesJson) as List<dynamic>)
        Quote.fromJson(q as Map<String, dynamic>),
    ];
    final situations = {
      for (final s in jsonDecode(situationsJson) as List<dynamic>)
        (s as Map<String, dynamic>)['id'] as String: Situation.fromJson(s),
    };
    final sources = [
      for (final s in jsonDecode(sourcesJson) as List<dynamic>)
        SourceCredit.fromJson(s as Map<String, dynamic>),
    ];
    return Content(quotes: quotes, situations: situations, sources: sources);
  }

  final List<Quote> quotes;
  final Map<String, Situation> situations;
  final List<SourceCredit> sources;
  final Map<String, Quote> _byId;

  Quote? quote(String id) => _byId[id];
}

Future<Content> loadContent([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  return Content.fromJson(
    quotesJson: await b.loadString('assets/content/quotes.json'),
    situationsJson: await b.loadString('assets/embedding/situations.json'),
    sourcesJson: await b.loadString('assets/content/sources.json'),
  );
}
