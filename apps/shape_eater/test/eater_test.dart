import 'package:flutter_test/flutter_test.dart';
import 'package:shapeeater/logic/eater.dart';

SeWorld calm() => SeWorld(difficulty: 1, seed: 1)..spawning = false;

void main() {
  test('eating a matching shape scores and starts a combo', () {
    final w = calm();
    w.items.add(Item(w.shape, w.px, w.py));
    w.step(0.01);
    expect(w.score, 10);
    expect(w.combo, 1);
    expect(w.items, isEmpty);
  });

  test('wrong shape costs a life and resets combo', () {
    final w = calm();
    w.combo = 4;
    w.comboTimer = 1;
    w.items.add(Item(Shape.square, w.px, w.py));
    w.step(0.01);
    expect(w.lives, 2);
    expect(w.combo, 0);
  });

  test('shield absorbs one hit', () {
    final w = calm()..shield = 5;
    w.items.add(Item(Shape.triangle, w.px, w.py));
    w.step(0.01);
    expect(w.lives, 3);
    expect(w.shield, 0);
  });

  test('combo multiplier grows with quick meals', () {
    final w = calm();
    for (var i = 0; i < 3; i++) {
      w.items.add(Item(w.shape, w.px, w.py));
      w.step(0.01);
    }
    expect(w.combo, 3);
    expect(w.multiplier, 2);
  });

  test('shape changes after five meals', () {
    final w = calm();
    final first = w.shape;
    for (var i = 0; i < 5; i++) {
      w.items.add(Item(w.shape, w.px, w.py));
      w.step(0.01);
    }
    expect(w.shape, isNot(first));
    expect(w.eatenInShape, 0);
  });

  test('chain reaction pops nearby matching shapes', () {
    final w = calm();
    w.items.add(Item(w.shape, w.px, w.py));
    w.items.add(Item(w.shape, w.px + 0.1, w.py));
    w.items.add(Item(Shape.square, w.px + 0.1, w.py + 0.05));
    w.step(0.01);
    expect(w.eatenStage, 2);
    expect(w.items.length, 1);
  });

  test('shape-change interval and targets vary by stage', () {
    expect(SeWorld(difficulty: 1, seed: 1).shapeEvery, 5);
    expect(SeWorld(difficulty: 2, seed: 1).shapeEvery, 6);
    expect(SeWorld(difficulty: 3, seed: 1).shapeEvery, 4);
    expect(SeWorld(difficulty: 100, seed: 1).effDifficulty, lessThan(60));
    expect(SeWorld(difficulty: 100, seed: 1).target, greaterThan(SeWorld(difficulty: 1, seed: 1).target));
  });

  test('stage completes at target and game over at zero lives', () {
    final w = calm();
    expect(w.stageDone, false);
    w.eatenStage = w.target;
    expect(w.stageDone, true);
    w.lives = 0;
    expect(w.over, true);
  });

  test('spawning is deterministic, capped and difficulty adds bars', () {
    final a = SeWorld(difficulty: 20, seed: 9), b = SeWorld(difficulty: 20, seed: 9);
    for (var i = 0; i < 600; i++) {
      a.step(1 / 60);
      b.step(1 / 60);
      a.lives = 3;
      b.lives = 3;
    }
    expect(a.items.length, b.items.length);
    expect(a.items.length, lessThanOrEqualTo(14));
    expect(a.bars.length, greaterThan(0));
    expect(SeWorld(difficulty: 1, seed: 1).bars, isEmpty);
  });
}
