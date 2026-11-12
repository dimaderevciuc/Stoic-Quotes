import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stoic_quotes/features/explore/shuffle_bag.dart';

void main() {
  test('every quote once per round, then a new round', () {
    final ids = [for (var i = 0; i < 20; i++) 'q$i'];
    final bag = ShuffleBag(ids, {}, random: Random(1));
    final round = [for (var i = 0; i < 20; i++) bag.draw()];
    expect(round.toSet(), ids.toSet());
    expect(bag.remaining, 0);
    final last = round.last;
    final next = bag.draw(avoid: last);
    expect(bag.startedNewRound, isTrue);
    expect(next, isNot(last));
  });

  test('already seen ids from storage are skipped', () {
    final bag = ShuffleBag(
      ['a', 'b', 'c'],
      {'a', 'b', 'gone'},
      random: Random(2),
    );
    expect(bag.remaining, 1);
    expect(bag.draw(), 'c');
  });
}
