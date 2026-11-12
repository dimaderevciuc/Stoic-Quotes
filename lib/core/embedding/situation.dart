/// A pre-written, reviewed situation (exported to assets/embedding/situations.json).
library;

class Situation {
  const Situation({
    required this.id,
    required this.title,
    required this.category,
    required this.quoteIds,
    required this.applications,
    required this.exercise,
    required this.isSensitive,
  });

  factory Situation.fromJson(Map<String, dynamic> json) => Situation(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    quoteIds: [for (final q in json['quote_ids'] as List<dynamic>) q as String],
    applications: {
      for (final e in (json['applications'] as Map<String, dynamic>).entries)
        e.key: e.value as String,
    },
    exercise: [
      for (final step in json['exercise'] as List<dynamic>) step as String,
    ],
    isSensitive: json['is_sensitive'] as bool,
  );

  final String id;
  final String title;
  final String category;

  /// Hand-picked quotes, in the order they should be shown.
  final List<String> quoteIds;

  /// Quote id to how this quote applies to the situation.
  final Map<String, String> applications;

  /// Two to four short steps.
  final List<String> exercise;

  /// Abuse, grief, illness: the UI shows help resources and extra care.
  final bool isSensitive;
}
