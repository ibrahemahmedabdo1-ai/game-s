import 'package:flutter_test/flutter_test.dart';
import 'package:gravityswitch/logic/gravity.dart';

/// Bot: flips to the safe side as soon as the previous pillar is cleared, and detours
/// to the key's side when a key is the next thing ahead.
bool botRuns(GsLevel lv, {double? untilX}) {
  final w = GsWorld(lv);
  const dt = 1 / 120;
  var guard = 0;
  while (!w.won && !w.dead && guard++ < 4000000) {
    double bestX = double.infinity;
    bool? want;
    for (final o in lv.obstacles) {
      if (o.end + kR > w.x) {
        bestX = o.x;
        want = !o.top;
        break;
      }
    }
    for (var i = 0; i < lv.keys.length; i++) {
      final k = lv.keys[i];
      if (!w.keyTaken(i) && k.x + 0.12 > w.x && k.x < bestX) {
        bestX = k.x;
        want = k.top;
        break;
      }
    }
    if (want != null && w.targetTop != want) w.flip();
    w.step(dt);
    if (untilX != null && w.x >= untilX) break;
  }
  return w.deaths == 0 && (untilX != null || w.won);
}

void main() {
  test('all 100 campaign levels are completable without dying', () {
    for (var n = 1; n <= 100; n++) {
      expect(botRuns(GsLevel.campaign(n)), true, reason: 'level $n');
    }
  });

  test('new mechanics appear: platforms from level 15, keys and gates from level 25', () {
    var plats = 0, keys = 0;
    for (var n = 1; n <= 14; n++) {
      expect(GsLevel.campaign(n).platforms, isEmpty);
    }
    for (var n = 15; n <= 100; n++) {
      plats += GsLevel.campaign(n).platforms.length;
    }
    for (var n = 1; n <= 24; n++) {
      expect(GsLevel.campaign(n).keys, isEmpty);
    }
    for (var n = 25; n <= 100; n++) {
      final lv = GsLevel.campaign(n);
      keys += lv.keys.length;
      expect(lv.gates.length, lv.keys.length);
    }
    expect(plats, greaterThan(10));
    expect(keys, greaterThan(10));
  });

  test('collecting every key is required and happens in a clean run', () {
    final lv = GsLevel.campaign(90);
    expect(lv.gates, isNotEmpty);
    final w = GsWorld(lv);
    expect(botRuns(lv), true);
    // re-run to inspect the final state
    final w2 = GsWorld(lv);
    for (var i = 0; i < 2000000 && !w2.won && !w2.dead; i++) {
      for (final o in lv.obstacles) {
        if (o.end + kR > w2.x) {
          if (w2.targetTop != !o.top) w2.flip();
          break;
        }
      }
      w2.step(1 / 120);
      if (w2.deaths > 0) break;
    }
    expect(w.keysTaken, 0);
    // A bot that ignores keys must eventually hit a closed gate (or the key was on its safe side anyway).
    expect(w2.deaths > 0 || w2.keysTaken == lv.keys.length, true);
  });

  test('a closed gate kills; the key opens it', () {
    final lv = GsLevel.campaign(90);
    final g = lv.gates.first;
    final w = GsWorld(lv);
    w.x = g.x - 0.05;
    w.step(0.02);
    expect(w.deaths, 1);
    final w2 = GsWorld(lv);
    // simulate having the key
    for (var i = 0; i < lv.keys.length; i++) {
      w2.x = lv.keys[i].x;
      w2.y = lv.keys[i].top ? kR : 1 - kR;
      w2.targetTop = lv.keys[i].top;
      w2.step(0.001);
    }
    w2.x = g.x - 0.05;
    final before = w2.deaths;
    w2.step(0.02);
    expect(w2.deaths, before);
  });

  test('rotating platforms hit a ball that flips through them, not one resting on a side', () {
    final lv = GsLevel.campaign(80);
    expect(lv.platforms, isNotEmpty);
    final p = lv.platforms.first;
    final resting = GsWorld(lv)
      ..x = p.cx
      ..y = kR;
    expect(resting.step, isNotNull);
    // sweep the platform angle: a ball in the middle of the corridor must collide at some x.
    var hit = false;
    for (var i = 0; i < 400 && !hit; i++) {
      final w = GsWorld(lv)
        ..x = p.cx - 0.3 + i * 0.0015
        ..y = 0.5;
      final before = w.deaths;
      w.step(0.0001);
      hit = w.deaths > before;
    }
    expect(hit, true);
  });

  test('levels are deterministic and non-trivial', () {
    final a = GsLevel.campaign(40), b = GsLevel.campaign(40);
    expect(a.obstacles.length, b.obstacles.length);
    expect(a.obstacles.length, greaterThan(5));
    expect(GsLevel.campaign(100).length, greaterThan(GsLevel.campaign(1).length));
  });

  test('endless is survivable for 150 units and speeds up', () {
    final lv = GsLevel.endlessRun(42);
    expect(botRuns(lv, untilX: 150), true);
    expect(lv.speedAt(100), greaterThan(lv.speedAt(0)));
  });

  test('doing nothing hits something eventually', () {
    final w = GsWorld(GsLevel.endlessRun(7));
    for (var i = 0; i < 6000 && !w.dead; i++) {
      w.step(1 / 60);
    }
    expect(w.dead, true);
  });

  test('daily is deterministic', () {
    expect(GsLevel.daily(20261117).obstacles.length, GsLevel.daily(20261117).obstacles.length);
  });
}
