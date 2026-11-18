import 'package:colorreactor/logic/reactor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays a level optimally: toggles the switch, rotates path tiles, and "waits"
/// on a spare tile when a hazard is frozen over the tile it needs.
bool solveWithBot(ReactorState st) {
  final lv = st.lv;
  final waitCells = [for (var i = 0; i < lv.w * lv.h; i++) if (!lv.path.contains(i) && i != lv.switchCell) i];
  var guard = 0;
  while (!st.solved && guard++ < 800) {
    int? target;
    if (lv.switchCell != null && !st.switchOn) {
      target = lv.switchCell;
    } else {
      for (final i in lv.path) {
        if (!lv.locked.contains(i) && st.masks[i] != lv.solution[i]) {
          target = i;
          break;
        }
      }
    }
    if (target == null) return false;
    if (st.frozen.contains(target)) {
      final spare = waitCells.firstWhere((c) => !st.frozen.contains(c));
      st.tap(spare);
    } else if (st.tap(target) == Tap.jammed) {
      return false;
    }
  }
  return st.solved;
}

void main() {
  test('all 100 campaign levels are solvable within the move limit, scrambled, deterministic', () {
    for (var n = 1; n <= 100; n++) {
      final a = ReactorLevel.campaign(n);
      final b = ReactorLevel.campaign(n);
      expect(a.start, b.start, reason: 'level $n deterministic');
      expect(a.isSolved(a.solution), true, reason: 'level $n solution valid');
      expect(a.isSolved(a.start), false, reason: 'level $n starts unsolved');
      final st = ReactorState(a);
      expect(solveWithBot(st), true, reason: 'level $n bot solves');
      expect(st.used, lessThanOrEqualTo(a.maxMoves), reason: 'level $n within move limit');
    }
  });

  test('new mechanics appear at the planned difficulty', () {
    expect(ReactorLevel.campaign(1).capacity, isEmpty);
    expect(ReactorLevel.campaign(60).capacity, isNotEmpty);
    expect(ReactorLevel.campaign(10).tracks, isEmpty);
    expect(ReactorLevel.campaign(60).tracks, isNotEmpty);
    expect(ReactorLevel.campaign(80).switchCell, isNotNull);
    expect(ReactorLevel.campaign(80).gateCells, isNotEmpty);
    expect(ReactorLevel.campaign(100).locked, isNotEmpty);
  });

  test('gates block flow until the switch is on', () {
    final lv = ReactorLevel.campaign(80);
    expect(lv.isSolved(lv.solution, switchOn: false), false);
    expect(lv.isSolved(lv.solution, switchOn: true), true);
    final st = ReactorState(lv);
    expect(st.switchOn, false);
    expect(st.tap(lv.switchCell!) == Tap.toggled || st.frozen.isNotEmpty, true);
  });

  test('limited capacity pipes jam after their allowance', () {
    final lv = ReactorLevel(
        w: 4, h: 4, solution: List.filled(16, dE | dW), start: List.filled(16, dN | dS), locked: {},
        sourceRows: [0], targetRows: [0], par: 4, path: {0, 1, 2, 3}, capacity: {1: 2});
    final st = ReactorState(lv);
    expect(st.tap(1), Tap.rotated);
    expect(st.tap(1), Tap.rotated);
    expect(st.tap(1), Tap.jammed);
    expect(st.moves, 2);
    expect(st.remainingCapacity(1), 0);
  });

  test('wrong routing costs extra moves', () {
    // Two colors: source rows 0 and 1, targets swapped, tiles straight.
    final lv = ReactorLevel(
        w: 4, h: 4, solution: List.filled(16, dE | dW), start: List.filled(16, dE | dW), locked: {},
        sourceRows: [0, 1], targetRows: [1, 0], par: 2, path: {});
    final st = ReactorState(lv);
    expect(lv.misroutes(st.masks), 2);
    st.tap(15); // any move re-evaluates: both colors exit on the wrong rows
    expect(st.penalty, 2);
    expect(st.used, 3);
  });

  test('locked tiles ignore taps and hazards freeze tiles', () {
    final lv = ReactorLevel.campaign(100);
    final st = ReactorState(lv);
    expect(st.tap(lv.locked.first), Tap.locked);
    expect(st.moves, 0);
    expect(lv.frozenAt(0).length, lv.tracks.length);
  });

  test('difficulty ramps up; daily and endless deterministic', () {
    expect(ReactorLevel.sizeFor(1) < ReactorLevel.sizeFor(100), true);
    expect(ReactorLevel.colorsFor(1) < ReactorLevel.colorsFor(100), true);
    expect(ReactorLevel.daily(20261117).start, ReactorLevel.daily(20261117).start);
    expect(ReactorLevel.endless(3).solution, ReactorLevel.endless(3).solution);
  });

  test('rotCw cycles after 4 turns', () {
    expect(rotCw(rotCw(rotCw(rotCw(dN | dE)))), dN | dE);
  });
}
