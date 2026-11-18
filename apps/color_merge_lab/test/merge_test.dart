import 'package:colormergelab/logic/merge.dart';
import 'package:flutter_test/flutter_test.dart';

const l1 = Piece(Kind.normal, 1);
MergeState mk(List<Piece> seq, {int layout = 0, int goal = 0}) =>
    MergeState(layout: layouts[layout], seed: 1, fixed: seq, goal: goal);

void main() {
  test('three adjacent level-1 pieces merge into level 2 at the last placed cell', () {
    final s = mk([l1, l1, l1]);
    s.place(0);
    s.place(1);
    expect(s.cells.where((c) => c > 0).length, 2);
    s.place(2);
    expect(s.cells[2], 2);
    expect(s.cells.where((c) => c > 0).length, 1);
    expect(s.score, greaterThan(0));
    expect(s.maxLevel, 2);
  });

  test('chain reaction merges repeatedly', () {
    // Build two level-2 pieces adjacent to the merge cell so one placement chains twice.
    final s = mk([l1, l1, l1, l1, l1, l1, l1, l1, l1, l1, l1]);
    s.cells[0] = 2;
    s.cells[1] = 2;
    s.cells[5] = 1;
    s.cells[10] = 1;
    s.place(6); // (1,1): level1 group {5,6,10}... merges to 2 at 6, which joins 0,1? 1 is above 6
    expect(s.lastChain, greaterThanOrEqualTo(2));
    expect(s.cells[6], 3);
  });

  test('blockers cannot be used and occupied cells are rejected', () {
    final s = mk([l1, l1], layout: 1);
    expect(s.place(6), false);
    expect(s.place(0), true);
    expect(s.place(0), false);
  });

  test('bomb clears neighbors', () {
    final s = mk([const Piece(Kind.bomb)]);
    s.cells[1] = 3;
    s.cells[5] = 2;
    s.cells[0] = 0;
    s.place(0);
    expect(s.cells[1], 0);
    expect(s.cells[5], 0);
  });

  test('wild joins the biggest neighboring group', () {
    final s = mk([const Piece(Kind.wild)]);
    s.cells[1] = 2;
    s.cells[5] = 2;
    s.place(0);
    expect(s.cells[0], 3);
  });

  test('bonus cell doubles the merge score', () {
    final a = mk([l1, l1, l1], layout: 0);
    final b = mk([l1, l1, l1], layout: 0);
    a.place(11);
    a.place(13);
    a.place(12); // center bonus
    b.place(0);
    b.place(1);
    b.place(2);
    expect(a.score, b.score * 2);
  });

  test('undo restores state and is limited', () {
    final s = mk([l1, l1, l1, l1, l1, l1]);
    s.place(0);
    s.place(1);
    s.place(2);
    expect(s.undo(), true);
    expect(s.cells[2], 0);
    expect(s.idx, 2);
    s.undo();
    s.undo();
    expect(s.undosLeft, 0);
    expect(s.undo(), false);
    s.grantUndo();
    expect(s.undosLeft, 1);
  });

  test('game over when full, rescue frees space', () {
    final s = mk([l1]);
    // alternate levels so no accidental groups exist
    for (var i = 0; i < s.cells.length; i++) {
      s.cells[i] = (i % 2 == 0) ? 7 : 8;
    }
    expect(s.over, true);
    s.rescue();
    expect(s.over, false);
  });

  test('generated stage layouts are valid, deterministic and get harder', () {
    for (var s = 1; s <= 100; s++) {
      final l = layoutForStage(s);
      final l2 = layoutForStage(s);
      expect(l.blockers, l2.blockers);
      expect(l.blockers.toSet().intersection(l.bonus.toSet()), isEmpty, reason: 'stage $s');
      expect([...l.blockers, ...l.bonus].every((c) => c >= 0 && c < l.n * l.n), true);
      expect(l.n * l.n - l.blockers.length, greaterThanOrEqualTo(18));
    }
    expect(layoutForStage(1).blockers, isEmpty);
    expect(layoutForStage(100).blockers.length, greaterThan(layoutForStage(15).blockers.length));
    expect(layoutForStage(60).n, 6);
  });

  test('goal detection, determinism and stage goals', () {
    final s = mk([l1, l1, l1], goal: 2);
    s.place(0);
    s.place(1);
    expect(s.reachedGoal, false);
    s.place(2);
    expect(s.reachedGoal, true);
    final a = MergeState(layout: layouts[0], seed: 5), b = MergeState(layout: layouts[0], seed: 5);
    expect([for (var i = 0; i < 20; i++) a.pieceAt(i).level], [for (var i = 0; i < 20; i++) b.pieceAt(i).level]);
    expect(MergeState.goalFor(1), 4);
    expect(MergeState.goalFor(26), 5);
    expect(MergeState.goalFor(100), 7);
  });
}
