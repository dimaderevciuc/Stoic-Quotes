/// Explore "For you": quotes from the person's picks, taking turns between
/// picks so a big one (self-discipline, 120 quotes) never drowns out a small
/// one (loss, about 60). Nothing repeats until everything has been shown.
library;

import 'dart:math';

import '../content/content_repository.dart';
import 'focus_areas.dart';

class ForYouPick {
  const ForYouPick(this.quoteId, this.area);

  final String quoteId;

  /// The pick this quote was chosen for (shown on the card).
  final FocusArea area;
}

class ForYouFeed {
  ForYouFeed(List<FocusArea> areas, Content content, {Random? random})
    : _random = random ?? Random(),
      _areas = [
        for (final a in areas)
          if (a.quoteIds(content) case final ids when ids.isNotEmpty) (a, ids),
      ] {
    for (final (_, ids) in _areas) {
      _queues.add([]);
      _all.addAll(ids);
    }
  }

  final Random _random;
  final List<(FocusArea, List<String>)> _areas;
  final _queues = <List<String>>[];
  final _all = <String>{};
  final _shown = <String>{};
  int _turn = 0;

  bool get isEmpty => _areas.isEmpty;

  /// The next quote. [avoid] is the quote on screen, so a new round never
  /// starts with it.
  ForYouPick next({String? avoid}) {
    if (isEmpty) throw StateError('no picks');
    if (_shown.length >= _all.length) _shown.clear();
    // Each pick gets a turn; one that has nothing new left passes it on.
    for (var tries = 0; tries < _areas.length; tries++) {
      final i = _turn % _areas.length;
      _turn++;
      final id = _take(i, avoid);
      if (id != null) {
        _shown.add(id);
        return ForYouPick(id, _areas[i].$1);
      }
    }
    // Only [avoid] was left: start a new round (it may come first only if it
    // is the only quote there is).
    _shown.clear();
    return next(avoid: _all.length > 1 ? avoid : null);
  }

  String? _take(int i, String? avoid) {
    final queue = _queues[i];
    for (var refilled = false; ; refilled = true) {
      while (queue.isNotEmpty) {
        final id = queue.removeLast();
        if (!_shown.contains(id) && id != avoid) return id;
      }
      if (refilled) return null;
      queue.addAll(
        [
          for (final id in _areas[i].$2)
            if (!_shown.contains(id) && id != avoid) id,
        ]..shuffle(_random),
      );
    }
  }
}
