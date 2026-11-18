import 'dart:math';

// Connector bit masks.
const int dN = 1, dE = 2, dS = 4, dW = 8;
const List<int> allDirs = [dN, dE, dS, dW];

int rotCw(int m) => ((m << 1) | (m >> 3)) & 15;
int opposite(int d) => d == dN ? dS : d == dS ? dN : d == dE ? dW : dE;
int dRow(int d) => d == dN ? -1 : d == dS ? 1 : 0;
int dCol(int d) => d == dE ? 1 : d == dW ? -1 : 0;

class TraceResult {
  TraceResult(this.cells, this.reached, [this.exitRow = -1]);
  final List<int> cells; // visited cell indexes
  final bool reached; // reached its OWN target
  final int exitRow; // row it left the board on (-1 if it never exited)
}

/// A generated, always-solvable level.
///
/// Mechanics: rotate pipes (tap), locked pipes, limited-capacity pipes (only N
/// rotations), a switch that opens gate pipes, moving "freezer" hazards that
/// jam the pipe under them, and a move penalty for routing a color to the wrong target.
class ReactorLevel {
  ReactorLevel({
    required this.w,
    required this.h,
    required this.solution,
    required this.start,
    required this.locked,
    required this.sourceRows,
    required this.targetRows,
    required this.par,
    this.path = const {},
    this.capacity = const {},
    this.switchCell,
    this.gateCells = const {},
    this.tracks = const [],
  });
  final int w, h;
  final List<int> solution, start;
  final Set<int> locked, path, gateCells;
  final Map<int, int> capacity; // cell -> max rotations
  final int? switchCell;
  final List<List<int>> tracks; // moving hazard routes
  final List<int> sourceRows, targetRows;
  final int par;
  int get colors => sourceRows.length;
  int get maxMoves => par * 3 + 6 + tracks.length * 6;

  /// Cells frozen by hazards after [moves] counted moves (ping-pong along each track).
  Set<int> frozenAt(int moves) {
    final out = <int>{};
    for (final t in tracks) {
      final period = 2 * (t.length - 1);
      final k = moves % period;
      out.add(t[k < t.length ? k : period - k]);
    }
    return out;
  }

  TraceResult trace(List<int> m, int color, {bool switchOn = true}) {
    var r = sourceRows[color], c = 0, enter = dW;
    final cells = <int>[];
    for (var step = 0; step <= w * h; step++) {
      final idx = r * w + c;
      if (gateCells.contains(idx) && !switchOn) return TraceResult(cells, false);
      final mask = m[idx];
      if (mask & enter == 0) return TraceResult(cells, false);
      cells.add(idx);
      final out = mask & ~enter;
      if (out == 0 || (out & (out - 1)) != 0) return TraceResult(cells, false);
      if (out == dE && c == w - 1) return TraceResult(cells, r == targetRows[color], r);
      final nr = r + dRow(out), nc = c + dCol(out);
      if (nr < 0 || nr >= h || nc < 0 || nc >= w) return TraceResult(cells, false);
      r = nr;
      c = nc;
      enter = opposite(out);
    }
    return TraceResult(cells, false);
  }

  bool isSolved(List<int> m, {bool switchOn = true}) {
    for (var i = 0; i < colors; i++) {
      if (!trace(m, i, switchOn: switchOn).reached) return false;
    }
    return true;
  }

  /// Number of colors currently delivered to somebody else's target.
  int misroutes(List<int> m, {bool switchOn = true}) {
    var n = 0;
    for (var i = 0; i < colors; i++) {
      final t = trace(m, i, switchOn: switchOn);
      if (t.exitRow >= 0 && t.exitRow != targetRows[i]) n++;
    }
    return n;
  }

  int? hintCell(List<int> m) {
    for (var i = 0; i < m.length; i++) {
      if (locked.contains(i)) continue;
      if (path.contains(i) && m[i] != solution[i]) return i;
    }
    return null;
  }

  static int sizeFor(int difficulty) => (4 + (difficulty - 1) ~/ 20).clamp(4, 7);
  static int colorsFor(int difficulty) => (1 + (difficulty - 1) ~/ 25).clamp(1, 4);

  /// Difficulty 1..100 (values above clamp). Same inputs => same level.
  static ReactorLevel generate(int difficulty, int seed) {
    final d = difficulty.clamp(1, 100);
    for (var attempt = 0; attempt < 150; attempt++) {
      final lv = _tryGenerate(d, seed + attempt * 104729);
      if (lv != null) return lv;
    }
    return _fallback(d, seed);
  }

  static ReactorLevel? _tryGenerate(int d, int seed) {
    final rng = Random(seed);
    final size = sizeFor(d), k = colorsFor(d).clamp(1, size);
    final w = size, h = size;
    final srcRows = List.generate(h, (i) => i)..shuffle(rng);
    final tgtRows = List.generate(h, (i) => i)..shuffle(rng);
    final sources = srcRows.take(k).toList(), targets = tgtRows.take(k).toList();
    final blocked = <int>{};
    for (var i = 0; i < k; i++) {
      blocked.add(sources[i] * w);
      blocked.add(targets[i] * w + w - 1);
    }
    final solution = List<int>.filled(w * h, 0);
    final pathCells = <int>{};
    final paths = <List<int>>[];
    for (var i = 0; i < k; i++) {
      final startIdx = sources[i] * w, endIdx = targets[i] * w + w - 1;
      var budget = 3000;
      final er = endIdx ~/ w, ec = endIdx % w;
      blocked.remove(startIdx);
      blocked.remove(endIdx);
      final path = <int>[startIdx];
      final seen = <int>{startIdx};
      bool dfs(int cell) {
        if (cell == endIdx) return true;
        if (--budget < 0) return false;
        final r = cell ~/ w, c = cell % w;
        // Goal-directed with noise: keeps paths shorter so several colors fit.
        final scored = <MapEntry<int, double>>[
          for (final dir in allDirs)
            MapEntry(dir, ((r + dRow(dir) - er).abs() + (c + dCol(dir) - ec).abs()) + rng.nextDouble() * 2.0)
        ]..sort((a, b) => a.value.compareTo(b.value));
        for (final dir in scored.map((e) => e.key)) {
          final nr = r + dRow(dir), nc = c + dCol(dir);
          if (nr < 0 || nr >= h || nc < 0 || nc >= w) continue;
          final n = nr * w + nc;
          if (seen.contains(n) || blocked.contains(n) || pathCells.contains(n)) continue;
          seen.add(n);
          path.add(n);
          if (dfs(n)) return true;
          path.removeLast();
          seen.remove(n);
        }
        return false;
      }

      if (!dfs(startIdx)) return null;
      pathCells.addAll(path);
      paths.add(path);
    }
    int dirTo(int from, int to) {
      final dr = to ~/ w - from ~/ w, dc = to % w - from % w;
      return dr == -1 ? dN : dr == 1 ? dS : dc == 1 ? dE : dW;
    }

    for (final p in paths) {
      for (var j = 0; j < p.length; j++) {
        final prev = j == 0 ? dW : dirTo(p[j], p[j - 1]);
        final next = j == p.length - 1 ? dE : dirTo(p[j], p[j + 1]);
        solution[p[j]] = prev | next;
      }
    }
    // Decoy tiles fill the rest of the board.
    for (var i = 0; i < w * h; i++) {
      if (!pathCells.contains(i)) {
        solution[i] = rng.nextBool() ? (dN | dS) : (dN | dE);
        final rot = rng.nextInt(4);
        for (var q = 0; q < rot; q++) {
          solution[i] = rotCw(solution[i]);
        }
      }
    }
    // Locked tiles appear from level 15 and grow in number.
    final locked = <int>{};
    if (d >= 15) {
      final cand = pathCells.toList()..shuffle(rng);
      locked.addAll(cand.take(((d - 10) ~/ 12).clamp(1, 6)));
    }
    final start = List<int>.from(solution);
    var par = 0;
    for (final i in pathCells) {
      if (locked.contains(i)) continue;
      final k2 = rng.nextInt(4);
      var m = solution[i];
      for (var q = 0; q < k2; q++) {
        m = rotCw(m);
      }
      start[i] = m;
      par += _stepsToReach(m, solution[i]);
    }
    // Limited-capacity pipes (from level 10): can only be rotated exactly what they need, plus one.
    final capacity = <int, int>{};
    if (d >= 10) {
      final cand = pathCells.where((i) => !locked.contains(i) && _stepsToReach(start[i], solution[i]) > 0).toList()..shuffle(rng);
      for (final i in cand.take(min(5, 1 + d ~/ 15))) {
        capacity[i] = _stepsToReach(start[i], solution[i]) + 1;
      }
    }
    // Switch + gate pipes (from level 30): gates conduct only while the switch is ON.
    int? switchCell;
    final gates = <int>{};
    final decoys = [for (var i = 0; i < w * h; i++) if (!pathCells.contains(i)) i];
    if (d >= 30 && decoys.isNotEmpty) {
      switchCell = decoys[rng.nextInt(decoys.length)];
      final g = pathCells.toList()..shuffle(rng);
      gates.addAll(g.take(d >= 60 ? 2 : 1));
      par += 1; // one toggle
    }
    // Moving freezer hazards (from level 20) jam the pipe beneath them for a move.
    final tracks = <List<int>>[];
    if (d >= 20 && decoys.length >= 3) {
      final cnt = min(2, 1 + (d - 20) ~/ 40);
      for (var t = 0; t < cnt; t++) {
        final len = 3 + rng.nextInt(2);
        if (rng.nextBool()) {
          final r = rng.nextInt(h), c0 = rng.nextInt(w - len + 1);
          tracks.add([for (var q = 0; q < len; q++) r * w + c0 + q]);
        } else {
          final c = rng.nextInt(w), r0 = rng.nextInt(h - len + 1);
          tracks.add([for (var q = 0; q < len; q++) (r0 + q) * w + c]);
        }
      }
    }
    final lv = ReactorLevel(
        w: w, h: h, solution: solution, start: start, locked: locked,
        sourceRows: sources, targetRows: targets, par: par,
        path: pathCells, capacity: capacity, switchCell: switchCell, gateCells: gates, tracks: tracks);
    if (par < 2 || lv.isSolved(start) || !lv.isSolved(solution)) return null;
    return lv;
  }

  static int _stepsToReach(int from, int to) {
    var m = from;
    for (var s = 0; s < 4; s++) {
      if (m == to) return s;
      m = rotCw(m);
    }
    return 0;
  }

  /// Guaranteed-valid straight rows; only used if random generation fails.
  static ReactorLevel _fallback(int d, int seed) {
    final size = sizeFor(d), k = colorsFor(d).clamp(1, size);
    final solution = List<int>.filled(size * size, dN | dS);
    final start = List<int>.from(solution);
    final path = <int>{};
    for (var r = 0; r < k; r++) {
      for (var c = 0; c < size; c++) {
        solution[r * size + c] = dE | dW;
        start[r * size + c] = dN | dS;
        path.add(r * size + c);
      }
    }
    return ReactorLevel(
        w: size, h: size, solution: solution, start: start, locked: {},
        sourceRows: List.generate(k, (i) => i), targetRows: List.generate(k, (i) => i),
        par: k * size, path: path);
  }

  static ReactorLevel campaign(int level) => generate(level, 1000 + level * 7919);
  static ReactorLevel endless(int n) => generate(n + 5, 777000 + n * 31337);
  static ReactorLevel daily(int dailySeedValue) => generate(35 + dailySeedValue % 40, dailySeedValue);
}

enum Tap { rotated, toggled, frozen, jammed, locked }

/// Mutable play state for one attempt at a level.
class ReactorState {
  ReactorState(this.lv)
      : masks = List<int>.from(lv.start),
        switchOn = lv.switchCell == null;
  final ReactorLevel lv;
  final List<int> masks;
  bool switchOn;
  int moves = 0, penalty = 0, _lastMis = 0;
  final Map<int, int> rotations = {};

  int get used => moves + penalty;
  bool get solved => lv.isSolved(masks, switchOn: switchOn);
  Set<int> get frozen => lv.frozenAt(moves);
  int remainingCapacity(int cell) => (lv.capacity[cell] ?? 0) - (rotations[cell] ?? 0);

  Tap tap(int i) {
    if (lv.locked.contains(i)) return Tap.locked;
    final isFrozen = frozen.contains(i);
    if (!isFrozen && i != lv.switchCell) {
      final cap = lv.capacity[i];
      if (cap != null && (rotations[i] ?? 0) >= cap) return Tap.jammed;
    }
    moves++;
    Tap result;
    if (isFrozen) {
      result = Tap.frozen;
    } else if (i == lv.switchCell) {
      switchOn = !switchOn;
      result = Tap.toggled;
    } else {
      masks[i] = rotCw(masks[i]);
      rotations[i] = (rotations[i] ?? 0) + 1;
      result = Tap.rotated;
    }
    final mis = lv.misroutes(masks, switchOn: switchOn);
    if (mis > _lastMis) penalty += mis - _lastMis;
    _lastMis = mis;
    return result;
  }

  int? hint() {
    if (lv.switchCell != null && !switchOn) return lv.switchCell;
    return lv.hintCell(masks);
  }
}
