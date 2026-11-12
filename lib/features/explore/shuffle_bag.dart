/// Random order without repeats until every quote has been seen once
/// ("seen" is stored in user.db, so the round survives restarts).
library;

import 'dart:math';

class ShuffleBag {
  ShuffleBag(List<String> ids, Set<String> seen, {Random? random})
    : _ids = List.unmodifiable(ids),
      _seen = {...seen}..retainAll(ids),
      _random = random ?? Random();

  final List<String> _ids;
  final Set<String> _seen;
  final Random _random;

  /// True when the last [draw] started a new round (all had been seen).
  bool startedNewRound = false;

  int get remaining => _ids.length - _seen.length;

  /// Picks an unseen id and marks it seen. When none is left, starts a new
  /// round, avoiding [avoid] (the quote on screen) as the first pick.
  String draw({String? avoid}) {
    if (_ids.isEmpty) throw StateError('no quotes');
    startedNewRound = false;
    if (_seen.length >= _ids.length) {
      _seen.clear();
      startedNewRound = true;
    }
    final pool = [
      for (final id in _ids)
        if (!_seen.contains(id) && id != avoid) id,
    ];
    final pick = pool.isEmpty ? _ids.first : pool[_random.nextInt(pool.length)];
    _seen.add(pick);
    return pick;
  }
}
