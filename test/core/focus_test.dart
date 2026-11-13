import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/core/focus/focus_areas.dart';
import 'package:stoic_quotes/core/focus/for_you_feed.dart';

import '../helpers.dart';

void main() {
  final content = loadContentFromDisk();

  group('focus areas', () {
    test('12 areas with unique ids', () {
      expect(focusAreas, hasLength(12));
      expect({for (final a in focusAreas) a.id}, hasLength(12));
    });

    test('every area has plenty of quotes, all of them real', () {
      for (final a in focusAreas) {
        final ids = a.quoteIds(content);
        expect(ids.length, greaterThanOrEqualTo(40), reason: a.id);
        expect(ids.toSet(), hasLength(ids.length), reason: a.id);
        expect(ids.every((id) => content.quote(id) != null), isTrue);
      }
    });

    test('every suggestion is a situation', () {
      for (final a in focusAreas) {
        expect(a.suggestions, isNotEmpty, reason: a.id);
        for (final id in a.suggestions) {
          expect(content.situations[id], isNotNull, reason: '${a.id}: $id');
        }
      }
    });

    test('loss only offers comforting or hand-reviewed quotes', () {
      final loss = focusAreaById('loss')!;
      final reviewed = {
        for (final s in content.situations.values)
          if (s.isSensitive && (s.category == 'loss' || s.category == 'health'))
            ...s.quoteIds,
      };
      for (final id in loss.quoteIds(content)) {
        final q = content.quote(id)!;
        expect(
          reviewed.contains(id) || q.needs.any(FocusArea.gentleNeeds.contains),
          isTrue,
          reason: id,
        );
      }
    });

    test('unknown stored ids are ignored', () {
      expect(
        resolveFocusAreas(['calm', 'removed-area', 'loss']).map((a) => a.id),
        ['calm', 'loss'],
      );
    });

    test('suggestions: one per pick first, then the second ones', () {
      final picks = resolveFocusAreas(['discipline', 'calm']);
      final titles = suggestionTitles(picks, content, fallback: const ['x']);
      String t(String id) => content.situations[id]!.title;
      expect(titles, [
        t('procrastination'),
        t('overthinking'),
        t('no-routine'),
        t('worry-about-future'),
      ]);
      expect(suggestionTitles([], content, fallback: const ['x']), ['x']);
    });
  });

  group('For you feed', () {
    test('takes turns between picks', () {
      final picks = resolveFocusAreas(['loss', 'pushing-further', 'calm']);
      final feed = ForYouFeed(picks, content, random: Random(1));
      final order = [for (var i = 0; i < 9; i++) feed.next().area.id];
      expect(order, [
        for (var i = 0; i < 3; i++) ...['loss', 'pushing-further', 'calm'],
      ]);
    });

    test('no repeats until every quote was shown, then starts over', () {
      final picks = resolveFocusAreas(['loss', 'work']);
      final all = {for (final a in picks) ...a.quoteIds(content)};
      final feed = ForYouFeed(picks, content, random: Random(2));
      final seen = <String>{};
      String? last;
      for (var i = 0; i < all.length; i++) {
        final id = feed.next(avoid: last).quoteId;
        expect(seen.add(id), isTrue, reason: 'repeat at $i');
        last = id;
      }
      expect(seen, all);
      // The new round never starts with the quote on screen.
      expect(feed.next(avoid: last).quoteId, isNot(last));
    });

    test('each quote is labelled with a pick it belongs to', () {
      final picks = resolveFocusAreas(['best-self', 'temper', 'meaning']);
      final feed = ForYouFeed(picks, content, random: Random(3));
      for (var i = 0; i < 60; i++) {
        final pick = feed.next();
        expect(pick.area.quoteIds(content), contains(pick.quoteId));
      }
    });
  });
}
