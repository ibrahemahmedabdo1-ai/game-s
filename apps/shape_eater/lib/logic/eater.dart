import 'dart:math';

enum Shape { circle, square, triangle }

enum Power { shield, slow, magnet }

const double arenaW = 1.0, arenaH = 1.6;

class Item {
  Item(this.shape, this.x, this.y, {this.vx = 0, this.vy = 0, this.r = 0.045, this.power});
  Shape shape;
  Power? power;
  double x, y, vx, vy, r;
}

class Bar {
  Bar(this.x, this.y, this.w, this.vx);
  double x, y, w, vx;
  static const double half = 0.016;
}

class SeWorld {
  SeWorld({required this.difficulty, required int seed, this.endless = false}) : rng = Random(seed) {
    for (var i = 0; i < barCount; i++) {
      bars.add(Bar(rng.nextDouble() * 0.6, 0.3 + rng.nextDouble() * 0.7, 0.28, (rng.nextBool() ? 1 : -1) * (0.12 + rng.nextDouble() * 0.1)));
    }
  }

  final int difficulty;
  final bool endless;
  final Random rng;
  bool spawning = true;

  double px = 0.5, py = 1.2, tx = 0.5, ty = 1.2, radius = 0.05;
  Shape shape = Shape.circle;
  int score = 0, lives = 3, combo = 0, eatenInShape = 0, eatenStage = 0, stage = 1, bestCombo = 0;
  double comboTimer = 0, invuln = 0, shield = 0, slow = 0, magnet = 0, _spawnTimer = 0.4;
  final List<Item> items = [];
  final List<Bar> bars = [];
  final List<String> events = [];

  /// Campaign stages 1-30 ramp linearly, then slowly, so stage 100 stays playable.
  int get effDifficulty => endless ? difficulty + stage * 2 : (difficulty <= 30 ? difficulty : 30 + (difficulty - 30) ~/ 3);
  /// How many meals before the shape changes (varies per stage: 4, 5 or 6).
  int get shapeEvery => endless ? 5 : 4 + difficulty % 3;
  int get barCount => effDifficulty >= 6 ? min(4, effDifficulty ~/ 6) : 0;
  int get target => endless ? 15 : 10 + min(difficulty, 60) ~/ 2;
  bool get stageDone => !endless && eatenStage >= target;
  bool get over => lives <= 0;
  int get multiplier => min(5, 1 + combo ~/ 3);

  static Shape nextShape(Shape s) => Shape.values[(s.index + 1) % Shape.values.length];

  void _spawn() {
    final d = effDifficulty;
    final speed = 0.14 + 0.005 * d;
    final side = rng.nextInt(4);
    double x, y;
    switch (side) {
      case 0:
        x = rng.nextDouble() * arenaW;
        y = -0.05;
      case 1:
        x = rng.nextDouble() * arenaW;
        y = arenaH + 0.05;
      case 2:
        x = -0.05;
        y = rng.nextDouble() * arenaH;
      default:
        x = arenaW + 0.05;
        y = rng.nextDouble() * arenaH;
    }
    final gx = 0.15 + rng.nextDouble() * 0.7, gy = 0.2 + rng.nextDouble() * 1.2;
    final dx = gx - x, dy = gy - y, len = sqrt(dx * dx + dy * dy);
    final roll = rng.nextDouble();
    Power? power;
    Shape sh;
    if (roll < 0.07) {
      power = Power.values[rng.nextInt(3)];
      sh = shape;
    } else if (roll < max(0.36, 0.52 - effDifficulty * 0.003)) {
      sh = shape;
    } else {
      final others = Shape.values.where((s) => s != shape).toList();
      sh = others[rng.nextInt(others.length)];
    }
    items.add(Item(sh, x, y, vx: dx / len * speed, vy: dy / len * speed, r: 0.04 + rng.nextDouble() * 0.02, power: power));
  }

  void _eat(Item it) {
    combo = comboTimer > 0 ? combo + 1 : 1;
    comboTimer = 2.0;
    bestCombo = max(bestCombo, combo);
    score += 10 * multiplier;
    eatenStage++;
    eatenInShape++;
    radius = min(0.11, radius + 0.002);
    events.add('eat');
    // chain reaction: nearby matching shapes pop too
    final chained = items.where((o) => o != it && o.power == null && o.shape == it.shape && _dist(o.x, o.y, it.x, it.y) < 0.18).toList();
    for (final o in chained) {
      items.remove(o);
      score += 5 * multiplier;
      eatenStage++;
      events.add('chain');
    }
    if (endless && eatenStage >= stage * 15) stage++;
    if (eatenInShape >= shapeEvery) {
      eatenInShape = 0;
      shape = nextShape(shape);
      events.add('shape');
    }
  }

  void _hurt() {
    if (invuln > 0) return;
    if (shield > 0) {
      shield = 0;
      invuln = 0.6;
      events.add('shield');
      return;
    }
    lives--;
    combo = 0;
    comboTimer = 0;
    radius = max(0.045, radius - 0.01);
    invuln = 1.0;
    events.add('hurt');
  }

  static double _dist(double ax, double ay, double bx, double by) => sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by));

  void step(double dt) {
    if (over) return;
    // player follows finger
    final dx = tx - px, dy = ty - py, d = sqrt(dx * dx + dy * dy);
    final maxStep = 1.6 * dt;
    if (d > maxStep) {
      px += dx / d * maxStep;
      py += dy / d * maxStep;
    } else {
      px = tx;
      py = ty;
    }
    px = px.clamp(radius, arenaW - radius).toDouble();
    py = py.clamp(radius, arenaH - radius).toDouble();
    comboTimer = max(0, comboTimer - dt);
    if (comboTimer == 0) combo = 0;
    invuln = max(0, invuln - dt);
    shield = max(0, shield - dt);
    slow = max(0, slow - dt);
    magnet = max(0, magnet - dt);

    if (spawning) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0 && items.length < 14) {
        _spawn();
        _spawnTimer = max(0.35, 1.1 - effDifficulty * 0.025);
      }
    }
    final k = slow > 0 ? 0.4 : 1.0;
    for (final it in items) {
      it.x += it.vx * dt * k;
      it.y += it.vy * dt * k;
      if (magnet > 0 && it.power == null && it.shape == shape) {
        final ddx = px - it.x, ddy = py - it.y, dd = sqrt(ddx * ddx + ddy * ddy);
        if (dd < 0.45 && dd > 0.001) {
          it.x += ddx / dd * 0.35 * dt;
          it.y += ddy / dd * 0.35 * dt;
        }
      }
    }
    items.removeWhere((it) => it.x < -0.2 || it.x > arenaW + 0.2 || it.y < -0.2 || it.y > arenaH + 0.2);

    for (final b in bars) {
      b.x += b.vx * dt * k;
      if (b.x < 0) {
        b.x = 0;
        b.vx = b.vx.abs();
      } else if (b.x + b.w > arenaW) {
        b.x = arenaW - b.w;
        b.vx = -b.vx.abs();
      }
      final cx = px.clamp(b.x, b.x + b.w).toDouble(), cy = py.clamp(b.y - Bar.half, b.y + Bar.half).toDouble();
      if (_dist(px, py, cx, cy) < radius * 0.9) _hurt();
    }

    for (final it in List<Item>.from(items)) {
      if (!items.contains(it)) continue;
      if (_dist(px, py, it.x, it.y) < radius + it.r * 0.85) {
        items.remove(it);
        if (it.power != null) {
          switch (it.power!) {
            case Power.shield:
              shield = 8;
            case Power.slow:
              slow = 5;
            case Power.magnet:
              magnet = 6;
          }
          score += 15;
          events.add('power');
        } else if (it.shape == shape) {
          _eat(it);
        } else {
          _hurt();
        }
      }
    }
  }

  /// Rewarded continue.
  void revive() {
    lives = 1;
    invuln = 2.5;
    items.clear();
  }

  int get starRating => lives >= 3 ? 3 : (lives == 2 ? 2 : 1);
}
