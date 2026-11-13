/// A curated, public domain quote with its plain modern explanation.
library;

class Quote {
  const Quote({
    required this.id,
    required this.text,
    required this.author,
    required this.work,
    required this.citation,
    required this.translator,
    required this.year,
    required this.context,
    required this.explanation,
    required this.themes,
    this.needs = const [],
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    id: json['id'] as String,
    text: json['text'] as String,
    author: json['author'] as String,
    work: json['work'] as String,
    citation: json['citation'] as String,
    translator: json['translator'] as String,
    year: json['year'] as int,
    context: json['context'] as String,
    explanation: json['explanation'] as String,
    themes: [for (final t in json['themes'] as List<dynamic>) t as String],
    needs: [
      for (final n in json['needs'] as List<dynamic>? ?? const []) n as String,
    ],
  );

  final String id;

  /// Exact words of the public domain translation.
  final String text;
  final String author;
  final String work;

  /// For example "Meditations 4.3".
  final String citation;

  /// Empty for works written in English.
  final String translator;
  final int year;

  /// The full source passage, shown when the card is expanded.
  final String context;

  /// One to three plain sentences: what it means today. Shown first.
  final String explanation;
  final List<String> themes;

  /// What the quote offers the reader, e.g. calm, courage, comfort.
  final List<String> needs;

  /// "Meditations 4.3 · tr. George Long, 1862" (no dashes, house style).
  String get sourceLine {
    final edition = translator.isEmpty ? '$year' : 'tr. $translator, $year';
    return '$citation · $edition';
  }
}

/// One source text, for the credits on the About screen.
class SourceCredit {
  const SourceCredit({
    required this.author,
    required this.title,
    required this.translator,
    required this.year,
    required this.origin,
  });

  factory SourceCredit.fromJson(Map<String, dynamic> json) => SourceCredit(
    author: json['author'] as String,
    title: json['title'] as String,
    translator: json['translator'] as String,
    year: json['year'] as int,
    origin: json['origin'] as String,
  );

  final String author;
  final String title;
  final String translator;
  final int year;
  final String origin;
}
