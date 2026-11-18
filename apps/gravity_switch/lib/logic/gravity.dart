import 'dart:math';

/// World units: the corridor is 1.0 tall. The ball moves right at a speed in units/second.
const double kR = 0.06; // ball radius
const double kFlipTime = 0.22; // seconds to cross the corridor
const double kObsH = 0.34; // pillar height
const double kPlatHalf = 0.28; // rotating platform half length
const double kPlatRate = 5.0; // radians of rotation per world unit travelled

class Obstacle {
  const Obstacle(this.x, this.w, this.top);
  final double x, w;
  final bool top;
  double get end => x + w;
}

class Star {
  const Star(this.x, this.top);
  final double x;
  final bool top;
}

/// A bar spinning in the middle of the corridor. It never touches a ball resting on
/// floor or ceiling, so it punishes flipping gravity while crossing it.
class Platform {
  const Platform(this.cx, this.phase);
  final double cx, phase;
  double angleAt(double ballX) => phase + (ballX - cx) * kPlatRate;
}

/// A key sits on one side of the corridor; its gate stays closed until it is collected.
class KeyItem {
  const KeyItem(this.x, this.top);
  final double x;
  final bool top;
}

class Gate {
  const Gate(this.x, this.keyIdx);
  final double x;
  final int keyIdx;
  static const double w = 0.07;
  double get end => x + w;
}

class GsLevel {
  GsLevel._(this.length, this.endless, int seed, this.difficulty, this.baseSpeed) : _rng = Random(seed);
  final double length;
  final bool endless;
  final int difficulty;
  final double baseSpeed;
  final Random _rng;
  final List<Obstacle> obstacles = [];
  final List<Star> stars = [];
  final List<double> checkpoints = [];
  final List<Platform> platforms = [];
  final List<KeyItem> keys = [];
  final List<Gate> gates = [];
  double _cursorEnd = 0;
  bool? _lastTop;
  bool _first = true;

  double speedAt(double x) => endless ? min(1.25, baseSpeed + x * 0.004) : baseSpeed;

  /// Generates content up to world x = [upTo]. Spacing guarantees solvability:
  ///  * opposite-side pillars leave >= 2r + v(T+0.12) of clear distance,
  ///  * a key segment leaves room to flip to the key side and back,
  ///  * platforms sit only in gaps between same-side pillars (no flip needed there).
  void ensure(double upTo) {
    final limit = endless ? upTo : min(upTo, length - 1.2);
    while (true) {
      final v = speedAt(_cursorEnd);
      final top = _rng.nextBool();
      final sameSide = !_first && _lastTop == top;
      final useKey = !_first && difficulty >= 25 && _rng.nextDouble() < 0.18;
      final usePlat = !_first && !useKey && sameSide && difficulty >= 15 && _rng.nextDouble() < 0.35;
      double minGap;
      if (_first) {
        minGap = 1.3;
      } else if (useKey) {
        minGap = 2 * kR + v * (2 * kFlipTime + 0.12) + 0.2;
      } else if (usePlat) {
        minGap = 1.1;
      } else if (!sameSide) {
        minGap = 2 * kR + v * (kFlipTime + 0.12);
      } else {
        minGap = 0.3;
      }
      final extra = _rng.nextDouble() * max(0.12, 1.4 - difficulty * 0.012);
      final x = _cursorEnd + minGap + extra;
      final w = 0.12 + _rng.nextDouble() * 0.12;
      if (x + w + (useKey ? 0.6 : 0.0) > limit) break;
      if (useKey) {
        keys.add(KeyItem(_cursorEnd + kR + v * kFlipTime + 0.15, top));
      } else if (usePlat) {
        platforms.add(Platform(_cursorEnd + (x - _cursorEnd) / 2, _rng.nextDouble() * pi));
      } else if (!_first && _rng.nextDouble() < 0.55) {
        stars.add(Star((_cursorEnd + x) / 2, !top));
      }
      obstacles.add(Obstacle(x, w, top));
      _cursorEnd = x + w;
      _lastTop = top;
      _first = false;
      if (useKey) {
        final gx = _cursorEnd + 0.4;
        gates.add(Gate(gx, keys.length - 1));
        _cursorEnd = gx + Gate.w;
      }
    }
  }

  bool _validCheckpoint(double cp) {
    for (final g in gates) {
      if (keys[g.keyIdx].x - 0.5 < cp && cp < g.end + 0.2) return false;
    }
    return true;
  }

  void _finish() {
    if (obstacles.length < 6) return;
    for (final f in [1 / 3, 2 / 3]) {
      final target = length * f;
      final idxs = List.generate(obstacles.length - 1, (i) => i)..sort((a, b) => (obstacles[a].end - target).abs().compareTo((obstacles[b].end - target).abs()));
      for (final i in idxs) {
        final cp = (obstacles[i].end + obstacles[i + 1].x) / 2;
        if (_validCheckpoint(cp) && !checkpoints.contains(cp)) {
          checkpoints.add(cp);
          break;
        }
      }
    }
    checkpoints.sort();
  }

  static GsLevel campaign(int n) {
    final d = n.clamp(1, 100);
    final lv = GsLevel._(12 + d * 0.14, false, 5000 + d * 131, d, min(1.0, 0.62 + d * 0.004));
    lv.ensure(lv.length);
    lv._finish();
    return lv;
  }

  static GsLevel endlessRun(int seed) => GsLevel._(double.infinity, true, seed, 30, 0.62);

  static GsLevel daily(int dateSeed) {
    final d = 40 + dateSeed % 40;
    final lv = GsLevel._(16, false, dateSeed, d, min(1.0, 0.62 + d * 0.004));
    lv.ensure(lv.length);
    lv._finish();
    return lv;
  }
}

class GsWorld {
  GsWorld(this.level) {
    y = 1 - kR;
    level.ensure(6);
  }
  final GsLevel level;
  double x = 0, y = 0, time = 0, _cp = 0;
  bool targetTop = false, dead = false, won = false;
  int starsGot = 0, deaths = 0;
  int _from = 0, _sFrom = 0;
  final Set<Star> _taken = {};
  final Set<int> _keysTaken = {};
  int checkpointsReached = 0;

  int get keysTaken => _keysTaken.length;
  bool keyTaken(int i) => _keysTaken.contains(i);

  void flip() {
    if (dead || won) return;
    targetTop = !targetTop;
  }

  int get score => level.endless ? (x * 10).floor() + starsGot * 50 : starsGot * 100 + max(0, 500 - deaths * 100);

  bool _hit(Obstacle o) {
    final ry1 = o.top ? 0.0 : 1 - kObsH, ry2 = o.top ? kObsH : 1.0;
    final cx = x.clamp(o.x, o.end).toDouble(), cy = y.clamp(ry1, ry2).toDouble();
    final dx = x - cx, dy = y - cy;
    final r = kR * 0.92;
    return dx * dx + dy * dy < r * r;
  }

  bool _hitPlatform(Platform p) {
    final a = p.angleAt(x);
    final ca = cos(a) * kPlatHalf, sa = sin(a) * kPlatHalf;
    final ax = p.cx - ca, ay = 0.5 - sa, bx = p.cx + ca, by = 0.5 + sa;
    final abx = bx - ax, aby = by - ay;
    final u = (((x - ax) * abx + (y - ay) * aby) / (abx * abx + aby * aby)).clamp(0.0, 1.0);
    final dx = x - (ax + abx * u), dy = y - (ay + aby * u);
    final r = kR * 0.92 + 0.02;
    return dx * dx + dy * dy < r * r;
  }

  bool _hitGate(Gate g) {
    if (_keysTaken.contains(g.keyIdx)) return false;
    return x + kR * 0.92 > g.x && x - kR * 0.92 < g.end;
  }

  void _die() {
    deaths++;
    if (level.endless) {
      dead = true;
    } else {
      _respawn();
    }
  }

  void _respawn() {
    x = _cp;
    Obstacle? next;
    for (final o in level.obstacles) {
      if (o.x > x) {
        next = o;
        break;
      }
    }
    targetTop = next == null ? false : !next.top;
    y = targetTop ? kR : 1 - kR;
    _from = 0;
    _keysTaken.removeWhere((i) => level.keys[i].x >= _cp);
  }

  /// Rewarded-continue: jump just past the thing we hit (and open any gate in the way).
  void revive() {
    for (final o in level.obstacles) {
      if (o.end + kR > x - 0.01 && o.x - kR < x + 0.01) {
        x = o.end + kR + 0.1;
        break;
      }
    }
    for (final g in level.gates) {
      if (x + kR > g.x && x - kR < g.end) _keysTaken.add(g.keyIdx);
    }
    dead = false;
    _from = 0;
  }

  void step(double dt) {
    if (dead || won) return;
    time += dt;
    x += level.speedAt(x) * dt;
    final vy = (1 - 2 * kR) / kFlipTime;
    final ty = targetTop ? kR : 1 - kR;
    if (y < ty) {
      y = min(ty, y + vy * dt);
    } else if (y > ty) {
      y = max(ty, y - vy * dt);
    }
    level.ensure(x + 6);
    while (_from < level.obstacles.length && level.obstacles[_from].end < x - 1) {
      _from++;
    }
    for (var i = _from; i < level.obstacles.length; i++) {
      final o = level.obstacles[i];
      if (o.x > x + 0.5) break;
      if (_hit(o)) {
        _die();
        return;
      }
    }
    for (final p in level.platforms) {
      if ((p.cx - x).abs() < kPlatHalf + 0.15 && _hitPlatform(p)) {
        _die();
        return;
      }
    }
    for (final g in level.gates) {
      if (g.x > x + 0.5) break;
      if (g.end < x - 0.5) continue;
      if (_hitGate(g)) {
        _die();
        return;
      }
    }
    for (var i = 0; i < level.keys.length; i++) {
      final k = level.keys[i];
      if (k.x > x + 0.3) break;
      if (!_keysTaken.contains(i) && (k.x - x).abs() < 0.1 && (y - (k.top ? kR : 1 - kR)).abs() < 0.3) {
        _keysTaken.add(i);
      }
    }
    while (_sFrom < level.stars.length && level.stars[_sFrom].x < x - 1) {
      _sFrom++;
    }
    for (var i = _sFrom; i < level.stars.length; i++) {
      final s = level.stars[i];
      if (s.x > x + 0.2) break;
      if (!_taken.contains(s) && (s.x - x).abs() < 0.1 && (y - (s.top ? kR : 1 - kR)).abs() < 0.3) {
        _taken.add(s);
        starsGot++;
      }
    }
    for (final c in level.checkpoints) {
      if (c > _cp && x >= c) {
        _cp = c;
        checkpointsReached++;
      }
    }
    if (!level.endless && x >= level.length) won = true;
  }

  int get starRating => deaths == 0 ? 3 : (deaths <= 2 ? 2 : 1);
}
