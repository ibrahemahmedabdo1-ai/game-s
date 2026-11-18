import 'dart:math';

const double dW = 1.0, dH = 1.6; // arena size
const double ballR = 0.026, pegR = 0.022, gravity = 2.4, binTop = 1.42;
const double paddleHalf = 0.12, paddleThick = 0.012;
const List<double> paddleAngles = [-0.75, -0.4, 0.4, 0.75];
const int ballCount = 6;

class Peg {
  const Peg(this.x, this.y, {this.bumper = false});
  final double x, y;
  final bool bumper; // bouncier special obstacle
}

class Paddle {
  const Paddle(this.x, this.y, this.start);
  final double x, y;
  final int start; // initial angle index
}

class DropLevel {
  DropLevel({
    required this.pegs,
    required this.paddles,
    required this.mult,
    required this.spawnX,
    required this.maxMoves,
    required this.bestScore,
    required this.bestConfig,
    required this.passScore,
  });
  final List<Peg> pegs;
  final List<Paddle> paddles;
  final List<int> mult; // per bin multiplier (0 = trap bin)
  final List<double> spawnX; // deterministic drop positions
  final int maxMoves, bestScore, passScore;
  final List<int> bestConfig;

  int get bins => mult.length;
  List<int> get startConfig => [for (final p in paddles) p.start];

  /// Minimum number of taps to reach [config] from the start (taps advance the angle cyclically).
  int movesTo(List<int> config) {
    var m = 0;
    for (var i = 0; i < paddles.length; i++) {
      m += (config[i] - paddles[i].start + paddleAngles.length) % paddleAngles.length;
    }
    return m;
  }

  /// Score of a finished drop for the given paddle configuration.
  int evaluate(List<int> config) {
    final sim = DropSim(this, config);
    sim.runToEnd();
    return sim.score;
  }

  /// Generates a level; the best score is found by brute force over every
  /// paddle configuration, so the pass threshold is always reachable.
  static DropLevel generate(int difficulty, int seed) {
    final d = difficulty.clamp(1, 100);
    final rng = Random(seed);
    final nPaddles = min(3, 2 + d ~/ 40);
    final nPegs = 4 + d ~/ 6;
    final nBumpers = d >= 20 ? min(3, d ~/ 25) : 0;
    final nBins = 5;
    final good = 2 + (d < 50 ? 1 : 0);
    final mult = List<int>.filled(nBins, 0);
    final order = List.generate(nBins, (i) => i)..shuffle(rng);
    for (var i = 0; i < good; i++) {
      mult[order[i]] = i == 0 ? 3 : (i == 1 ? 2 : 1);
    }
    final pegs = <Peg>[];
    for (var i = 0; i < nPegs + nBumpers; i++) {
      pegs.add(Peg(0.12 + rng.nextDouble() * 0.76, 0.35 + rng.nextDouble() * 0.9, bumper: i >= nPegs));
    }
    final paddles = <Paddle>[
      for (var i = 0; i < nPaddles; i++)
        Paddle(0.2 + rng.nextDouble() * 0.6, 0.5 + (i + 0.5) * (0.85 / nPaddles), rng.nextInt(paddleAngles.length))
    ];
    final spawn = [for (var i = 0; i < ballCount; i++) 0.38 + rng.nextDouble() * 0.24];
    final tmp = DropLevel(pegs: pegs, paddles: paddles, mult: mult, spawnX: spawn, maxMoves: 0, bestScore: 0, bestConfig: const [], passScore: 0);
    var best = -1;
    var bestCfg = tmp.startConfig;
    var bestMoves = 1 << 20;
    final total = pow(paddleAngles.length, nPaddles).toInt();
    for (var code = 0; code < total; code++) {
      var c = code;
      final cfg = <int>[];
      for (var i = 0; i < nPaddles; i++) {
        cfg.add(c % paddleAngles.length);
        c ~/= paddleAngles.length;
      }
      final sc = tmp.evaluate(cfg);
      final mv = tmp.movesTo(cfg);
      if (sc > best || (sc == best && mv < bestMoves)) {
        best = sc;
        bestCfg = cfg;
        bestMoves = mv;
      }
    }
    // Pass requires at least ~45% of what is actually achievable.
    final pass = max(1, (best * 0.45).floor());
    return DropLevel(
        pegs: pegs,
        paddles: paddles,
        mult: mult,
        spawnX: spawn,
        maxMoves: bestMoves + 3,
        bestScore: best,
        bestConfig: bestCfg,
        passScore: pass);
  }

  static DropLevel campaign(int n) => generate(n, 31000 + n * 977);
  static DropLevel endless(int n) => generate(min(100, 10 + n * 3), 77000 + n * 4099);
  static DropLevel daily(int seed) => generate(30 + seed % 50, seed);
}

class Ball {
  Ball(this.x, this.y, this.spawnT);
  double x, y, vx = 0, vy = 0;
  final double spawnT;
  bool active = false, done = false;
  int bin = -1;
}

/// Deterministic lightweight physics (fixed step). Used for gameplay and for level validation.
class DropSim {
  DropSim(this.level, List<int> config) : config = List<int>.from(config) {
    for (var i = 0; i < level.spawnX.length; i++) {
      balls.add(Ball(level.spawnX[i], -0.05, i * 0.35));
    }
  }
  final DropLevel level;
  final List<int> config;
  final List<Ball> balls = [];
  double t = 0;
  static const double dt = 1 / 90;

  bool get finished => balls.every((b) => b.done);

  int get score {
    var s = 0;
    for (final b in balls) {
      if (b.bin >= 0) s += level.mult[b.bin];
    }
    return s;
  }

  int get inGood => balls.where((b) => b.bin >= 0 && level.mult[b.bin] > 0).length;
  bool get perfect => finished && inGood == balls.length;

  void runToEnd() {
    var guard = 0;
    while (!finished && guard++ < 2000) {
      step();
    }
  }

  void _collideCircle(Ball b, double cx, double cy, double r, double e) {
    final dx = b.x - cx, dy = b.y - cy;
    final dist = sqrt(dx * dx + dy * dy);
    final minD = ballR + r;
    if (dist < minD && dist > 1e-9) {
      final nx = dx / dist, ny = dy / dist;
      b.x = cx + nx * minD;
      b.y = cy + ny * minD;
      final vn = b.vx * nx + b.vy * ny;
      if (vn < 0) {
        b.vx -= (1 + e) * vn * nx;
        b.vy -= (1 + e) * vn * ny;
      }
    }
  }

  void _collidePaddle(Ball b, Paddle p, double angle) {
    final ca = cos(angle), sa = sin(angle);
    final ax = p.x - ca * paddleHalf, ay = p.y - sa * paddleHalf;
    final bx = p.x + ca * paddleHalf, by = p.y + sa * paddleHalf;
    final abx = bx - ax, aby = by - ay;
    final u = (((b.x - ax) * abx + (b.y - ay) * aby) / (abx * abx + aby * aby)).clamp(0.0, 1.0);
    _collideCircle(b, ax + abx * u, ay + aby * u, paddleThick, 0.35);
  }

  void step() {
    t += dt;
    for (final b in balls) {
      if (b.done) continue;
      if (!b.active) {
        if (t >= b.spawnT) {
          b.active = true;
        } else {
          continue;
        }
      }
      b.vy += gravity * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.x < ballR) {
        b.x = ballR;
        b.vx = b.vx.abs() * 0.5;
      } else if (b.x > dW - ballR) {
        b.x = dW - ballR;
        b.vx = -b.vx.abs() * 0.5;
      }
      for (final p in level.pegs) {
        _collideCircle(b, p.x, p.y, pegR, p.bumper ? 1.15 : 0.5);
      }
      for (var i = 0; i < level.paddles.length; i++) {
        _collidePaddle(b, level.paddles[i], paddleAngles[config[i]]);
      }
      // keep the ball from stalling horizontally
      if (b.vy.abs() < 0.02 && b.y < binTop) b.vx += (b.x < 0.5 ? -1 : 1) * 0.02;
      if (b.y >= binTop) {
        b.done = true;
        b.bin = (b.x * level.bins).floor().clamp(0, level.bins - 1);
      } else if (t - b.spawnT > 9) {
        b.done = true; // stuck: counts as a miss
        b.bin = -1;
      }
    }
  }
}
