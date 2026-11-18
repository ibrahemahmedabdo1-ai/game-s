import 'package:flutter_test/flutter_test.dart';
import 'package:perfectdrop/logic/drop.dart';

void main() {
  test('every level has a reachable pass score and best config within the move limit', () {
    for (var n = 1; n <= 100; n += 3) {
      final lv = DropLevel.campaign(n);
      expect(lv.bestScore, greaterThan(0), reason: 'level $n has a scoring configuration');
      expect(lv.evaluate(lv.bestConfig), lv.bestScore, reason: 'level $n deterministic');
      expect(lv.passScore, lessThanOrEqualTo(lv.bestScore));
      expect(lv.movesTo(lv.bestConfig), lessThanOrEqualTo(lv.maxMoves));
    }
  });

  test('simulation is deterministic and finishes', () {
    final lv = DropLevel.campaign(7);
    final a = DropSim(lv, lv.startConfig)..runToEnd();
    final b = DropSim(lv, lv.startConfig)..runToEnd();
    expect(a.finished, true);
    expect(a.score, b.score);
    expect(a.balls.every((x) => x.done), true);
  });

  test('a ball with no obstacles falls straight into the middle bin', () {
    final lv = DropLevel(pegs: const [], paddles: const [], mult: const [0, 0, 3, 0, 0], spawnX: const [0.5], maxMoves: 0, bestScore: 3, bestConfig: const [], passScore: 1);
    final sim = DropSim(lv, const [])..runToEnd();
    expect(sim.score, 3);
    expect(sim.perfect, true);
  });

  test('movesTo counts cyclic taps', () {
    final lv = DropLevel(pegs: const [], paddles: const [Paddle(0.5, 0.8, 1)], mult: const [1], spawnX: const [0.5], maxMoves: 0, bestScore: 0, bestConfig: const [], passScore: 0);
    expect(lv.movesTo([1]), 0);
    expect(lv.movesTo([0]), 3);
    expect(lv.movesTo([2]), 1);
  });

  test('difficulty adds obstacles', () {
    expect(DropLevel.campaign(90).pegs.length, greaterThan(DropLevel.campaign(1).pegs.length));
  });
}
