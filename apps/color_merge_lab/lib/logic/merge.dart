import 'dart:math';

enum Kind { normal, wild, bomb }

class Piece {
  const Piece(this.kind, [this.level = 1]);
  final Kind kind;
  final int level;
}

class Layout {
  const Layout(this.n, this.blockers, this.bonus);
  final int n;
  final List<int> blockers, bonus;
}

const layouts = [
  Layout(5, [], [12]),
  Layout(5, [6, 8, 16, 18], [12]),
  Layout(6, [14, 15, 20, 21], [0, 5, 30, 35]),
  Layout(5, [2, 10, 14, 22], [12]),
];

const int maxPieceLevel = 12;

/// Campaign layout for stage 1..100: board grows to 6x6 after stage 50, more blockers and
/// bonus cells appear as stages advance. Deterministic per stage.
Layout layoutForStage(int stage) {
  final s = stage.clamp(1, 100);
  final n = s > 50 ? 6 : 5;
  final rng = Random(8100 + s * 31);
  final cells = List.generate(n * n, (i) => i)..shuffle(rng);
  final blockerCount = min(n * n - 18, s ~/ 14);
  final blockers = cells.take(blockerCount).toList()..sort();
  final bonus = cells.skip(blockerCount).take(1 + s % 3).toList()..sort();
  return Layout(n, blockers, bonus);
}

class _Snap {
  _Snap(this.cells, this.idx, this.score, this.maxLevel);
  final List<int> cells;
  final int idx, score, maxLevel;
}

/// Cell values: 0 empty, -1 blocker, >0 piece level.
class MergeState {
  MergeState({required this.layout, required int seed, this.difficulty = 1, List<Piece>? fixed, this.goal = 0, this.maxUndos = 3})
      : _rng = Random(seed),
        _fixed = fixed,
        undosLeft = maxUndos {
    cells = List<int>.filled(layout.n * layout.n, 0);
    for (final b in layout.blockers) {
      cells[b] = -1;
    }
  }

  final Layout layout;
  final int difficulty, goal, maxUndos;
  final Random _rng;
  final List<Piece>? _fixed;
  final List<Piece> _seq = [];
  late List<int> cells;
  int idx = 0, score = 0, maxLevel = 0, undosLeft, bestChain = 0, lastChain = 0;
  final List<_Snap> _history = [];

  int get n => layout.n;
  bool get reachedGoal => goal > 0 && maxLevel >= goal;
  bool get over => !cells.contains(0);
  int get empties => cells.where((c) => c == 0).length;

  Piece _gen() {
    final f = _fixed;
    if (f != null && _seq.length < f.length) return f[_seq.length];
    final r = _rng.nextDouble();
    final wildP = max(0.02, 0.05 - difficulty * 0.001);
    if (r < 0.04) return const Piece(Kind.bomb);
    if (r < 0.04 + wildP) return const Piece(Kind.wild);
    final w1 = max(0.45, 0.72 - difficulty * 0.01);
    final x = _rng.nextDouble();
    if (x < w1) return const Piece(Kind.normal, 1);
    if (x < w1 + (1 - w1) * 0.7) return const Piece(Kind.normal, 2);
    return const Piece(Kind.normal, 3);
  }

  Piece pieceAt(int i) {
    while (_seq.length <= i) {
      _seq.add(_gen());
    }
    return _seq[i];
  }

  Piece get current => pieceAt(idx);
  List<Piece> upcoming(int k) => [for (var i = 1; i <= k; i++) pieceAt(idx + i)];

  List<int> _neighbors(int c) {
    final r = c ~/ n, col = c % n;
    return [
      if (r > 0) c - n,
      if (r < n - 1) c + n,
      if (col > 0) c - 1,
      if (col < n - 1) c + 1,
    ];
  }

  List<int> _group(int start, int level, List<int> board) {
    final seen = <int>{start};
    final stack = [start];
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      for (final nb in _neighbors(c)) {
        if (board[nb] == level && seen.add(nb)) stack.add(nb);
      }
    }
    return seen.toList();
  }

  /// Places the current piece. Returns false if the cell is not empty.
  bool place(int c) {
    if (over || c < 0 || c >= cells.length || cells[c] != 0) return false;
    _history.add(_Snap(List<int>.from(cells), idx, score, maxLevel));
    if (_history.length > maxUndos + 1) _history.removeAt(0);
    final p = current;
    lastChain = 0;
    if (p.kind == Kind.bomb) {
      var removed = 0;
      for (final nb in _neighbors(c)) {
        if (cells[nb] > 0) {
          cells[nb] = 0;
          removed++;
        }
      }
      score += 10 * removed;
    } else {
      var level = p.level;
      if (p.kind == Kind.wild) {
        var bestSize = 0;
        level = 1;
        for (final nb in _neighbors(c)) {
          final l = cells[nb];
          if (l <= 0) continue;
          final test = List<int>.from(cells)..[c] = l;
          final size = _group(c, l, test).length;
          if (size > bestSize) {
            bestSize = size;
            level = l;
          }
        }
      }
      cells[c] = level;
      var chain = 0;
      while (true) {
        final lvl = cells[c];
        final g = _group(c, lvl, cells);
        if (g.length < 3 || lvl >= maxPieceLevel) break;
        for (final i in g) {
          cells[i] = 0;
        }
        cells[c] = lvl + 1;
        chain++;
        final mult = layout.bonus.contains(c) ? 2 : 1;
        score += lvl * 10 * g.length * chain * mult;
        maxLevel = max(maxLevel, lvl + 1);
      }
      lastChain = chain;
      bestChain = max(bestChain, chain);
      maxLevel = max(maxLevel, cells[c]);
    }
    idx++;
    return true;
  }

  bool undo() {
    if (undosLeft <= 0 || _history.isEmpty) return false;
    final s = _history.removeLast();
    cells = List<int>.from(s.cells);
    idx = s.idx;
    score = s.score;
    maxLevel = s.maxLevel;
    undosLeft--;
    return true;
  }

  void grantUndo() => undosLeft++;

  /// Rewarded continue: clears up to four of the lowest-level pieces.
  void rescue() {
    final idxs = [for (var i = 0; i < cells.length; i++) if (cells[i] > 0) i]..sort((a, b) => cells[a].compareTo(cells[b]));
    for (final i in idxs.take(4)) {
      cells[i] = 0;
    }
    _history.clear();
  }

  /// Target piece level: 4 for stages 1-25, then 5, 6, 7 (a 3-merge game needs 3^(L-1) units).
  static int goalFor(int stage) => min(7, 4 + (stage - 1) ~/ 25);
}
