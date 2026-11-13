/// The things a person can choose to focus on (intro and Explore "For you").
///
/// Titles name a direction, never the person: "Discipline & focus", not
/// "I procrastinate". The choices are taps, stored encrypted in user.db.
library;

import 'package:flutter/material.dart';

import '../content/content_repository.dart';
import '../content/quote.dart';

class FocusArea {
  const FocusArea({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.themes = const {},
    this.needs = const {},
    required this.suggestions,
    this.gentleOnly = false,
  });

  /// Stored in user.db, so never rename one.
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;

  /// A quote belongs here if it has any of these themes or needs...
  final Set<String> themes;
  final Set<String> needs;

  /// ...except for [gentleOnly] areas (loss), where it must also be comforting.
  final bool gentleOnly;

  /// Situation ids whose titles become the Reflect screen's suggestions.
  final List<String> suggestions;

  static const maxPicks = 5;

  /// Needs that make a quote comforting rather than stern.
  static const gentleNeeds = {'comfort', 'self-compassion'};

  bool matches(Quote q) {
    final tagged = q.themes.any(themes.contains) || q.needs.any(needs.contains);
    if (!tagged) return false;
    return !gentleOnly || q.needs.any(gentleNeeds.contains);
  }

  /// Every quote for this area, in corpus order. Loss also includes the quotes
  /// hand-picked (and reviewed as gentle) for the sensitive loss and health
  /// situations.
  List<String> quoteIds(Content content) {
    final ids = <String>{
      for (final q in content.quotes)
        if (matches(q)) q.id,
    };
    if (gentleOnly) {
      for (final s in content.situations.values) {
        if (s.isSensitive && (s.category == 'loss' || s.category == 'health')) {
          ids.addAll(s.quoteIds.where((id) => content.quote(id) != null));
        }
      }
    }
    return ids.toList();
  }
}

/// From reaching for more, through everyday life, to harder times.
const focusAreas = <FocusArea>[
  FocusArea(
    id: 'best-self',
    title: 'Becoming my best self',
    subtitle: 'Character, virtue, growing as a person',
    icon: Icons.trending_up,
    themes: {'character', 'virtue'},
    suggestions: ['want-to-be-better', 'mocked-for-changing'],
  ),
  FocusArea(
    id: 'pushing-further',
    title: 'Pushing further',
    subtitle: 'Drive, ambition, not settling',
    icon: Icons.bolt,
    needs: {'motivation', 'courage'},
    suggestions: ['give-up-easily', 'big-risk'],
  ),
  FocusArea(
    id: 'curiosity',
    title: 'Curiosity & learning',
    subtitle: 'Thinking clearly, learning for life',
    icon: Icons.lightbulb_outline,
    themes: {'learning', 'judgment', 'nature'},
    suggestions: ['what-to-study', 'slow-progress'],
  ),
  FocusArea(
    id: 'discipline',
    title: 'Discipline & focus',
    subtitle: 'Habits, starting, following through',
    icon: Icons.center_focus_strong,
    themes: {'self-discipline'},
    needs: {'discipline'},
    suggestions: ['procrastination', 'no-routine'],
  ),
  FocusArea(
    id: 'work',
    title: 'Work & success',
    subtitle: 'Doing good work, handling success and failure',
    icon: Icons.work_outline,
    themes: {'work', 'failure'},
    suggestions: ['overwhelmed-workload', 'stuck-in-job'],
  ),
  FocusArea(
    id: 'time',
    title: 'Making the most of time',
    subtitle: 'Living now, not later',
    icon: Icons.hourglass_bottom,
    themes: {'time', 'present-moment'},
    suggestions: ['wasting-life', 'too-busy'],
  ),
  FocusArea(
    id: 'calm',
    title: 'Calm under pressure',
    subtitle: 'Stress, worry, overthinking',
    icon: Icons.spa_outlined,
    themes: {'anxiety', 'fear'},
    needs: {'calm'},
    suggestions: ['overthinking', 'worry-about-future'],
  ),
  FocusArea(
    id: 'temper',
    title: 'Keeping my temper',
    subtitle: 'Anger, patience, letting go',
    icon: Icons.local_fire_department_outlined,
    themes: {'anger', 'patience'},
    needs: {'forgiveness'},
    suggestions: ['lost-my-temper', 'holding-grudge'],
  ),
  FocusArea(
    id: 'confidence',
    title: 'Confidence',
    subtitle: "Self-worth, other people's opinions",
    icon: Icons.shield_outlined,
    themes: {'opinion-of-others', 'humility'},
    suggestions: ['not-good-enough', 'comparing-myself'],
  ),
  FocusArea(
    id: 'people',
    title: 'People I care about',
    subtitle: 'Friends, family, love',
    icon: Icons.people_outline,
    themes: {'friendship', 'kindness', 'community'},
    suggestions: ['lonely', 'keep-arguing'],
  ),
  FocusArea(
    id: 'meaning',
    title: 'Meaning & purpose',
    subtitle: 'Direction, what matters, a life well lived',
    icon: Icons.explore_outlined,
    themes: {'duty', 'death', 'acceptance'},
    suggestions: ['no-purpose', 'waiting-to-live'],
  ),
  FocusArea(
    id: 'loss',
    title: 'Loss & hard times',
    subtitle: 'Grief, illness, setbacks',
    icon: Icons.favorite_border,
    themes: {'grief', 'adversity', 'pain'},
    gentleOnly: true,
    suggestions: ['anniversary-of-loss', 'life-not-as-planned'],
  ),
];

final _byId = {for (final a in focusAreas) a.id: a};

FocusArea? focusAreaById(String id) => _byId[id];

/// The stored ids that still exist, in the order the person picked them.
List<FocusArea> resolveFocusAreas(Iterable<String> ids) => [
  for (final id in ids) ?_byId[id],
];

/// Reflect screen suggestions: first suggestion of every pick, then the
/// second ones, so each pick shows up early. Falls back to [fallback].
List<String> suggestionTitles(
  List<FocusArea> picks,
  Content content, {
  required List<String> fallback,
}) {
  if (picks.isEmpty) return fallback;
  final titles = <String>[];
  for (var round = 0; round < 2; round++) {
    for (final a in picks) {
      if (round >= a.suggestions.length) continue;
      final title = content.situations[a.suggestions[round]]?.title;
      if (title != null && !titles.contains(title)) titles.add(title);
    }
  }
  return titles.isEmpty ? fallback : titles;
}
