import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_info.dart';
import 'logic/gravity.dart';

class GravityScreen extends StatefulWidget {
  const GravityScreen({super.key, required this.ctl, required this.mode, this.level = 1});
  final ShellController ctl;
  final PlayMode mode;
  final int level;
  @override
  State<GravityScreen> createState() => _GravityScreenState();
}

class _GravityScreenState extends State<GravityScreen> with WidgetsBindingObserver {
  late GsWorld world;
  bool paused = false, finished = false, _dialogOpen = false;
  ShellController get ctl => widget.ctl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    world = _make();
  }

  GsWorld _make() => GsWorld(switch (widget.mode) {
        PlayMode.campaign => GsLevel.campaign(widget.level),
        PlayMode.endless => GsLevel.endlessRun(DateTime.now().millisecondsSinceEpoch & 0xFFFFFF),
        PlayMode.daily => GsLevel.daily(dailySeed(DateTime.now())),
      });

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) {
      paused = true;
      ctl.audio.pauseMusic();
    } else if (s == AppLifecycleState.resumed) {
      ctl.audio.resumeMusic();
      if (!finished) _pause();
    }
  }

  void _update(double dt) {
    if (paused || finished) return;
    final before = world.deaths;
    final keysBefore = world.keysTaken;
    world.step(dt);
    if (world.deaths > before) {
      ctl.audio.buzz();
      ctl.audio.play('hurt');
    }
    if (world.keysTaken > keysBefore) ctl.audio.play('coin');
    if (world.won) {
      _win();
    } else if (world.dead) {
      _lose();
    }
    setState(() {});
  }

  Future<void> _win() async {
    finished = true;
    ctl.audio.play('win');
    final stars = world.starRating;
    final score = world.score;
    if (widget.mode == PlayMode.campaign) {
      await ctl.finishLevel(widget.level, stars, score);
    } else {
      final today = dayKey(DateTime.now());
      await ctl.commit(() {
        if (ctl.save.lastDailyChallenge != today) {
          ctl.save.lastDailyChallenge = today;
          ctl.save.coins += 20;
        }
        if (score > ctl.save.bestScore) ctl.save.bestScore = score;
        ctl.save.roundsPlayed++;
      });
    }
    if (!mounted) return;
    final last = widget.mode == PlayMode.campaign && widget.level >= ctl.info.levelCount;
    final c = await showResultDialog(context, ctl,
        title: ctl.t('levelComplete'),
        stars: stars,
        score: score,
        canNext: widget.mode == PlayMode.campaign && !last);
    if (!mounted) return;
    ctl.roundBreak();
    if (c == 'next') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => GravityScreen(ctl: ctl, mode: widget.mode, level: widget.level + 1)));
    } else if (c == 'restart') {
      _restart();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _lose() async {
    finished = true;
    ctl.audio.play('lose');
    final score = world.score;
    await ctl.commit(() {
      if (score > ctl.save.bestScore) ctl.save.bestScore = score;
      ctl.save.roundsPlayed++;
      ctl.save.coins += world.starsGot;
    });
    if (!mounted) return;
    final c = await showResultDialog(context, ctl, title: ctl.t('gameOver'), score: score, offerContinue: true);
    if (!mounted) return;
    if (c == 'continue') {
      if (await watchRewarded(context, ctl)) {
        world.revive();
        setState(() => finished = false);
      } else {
        _lose();
      }
    } else {
      ctl.roundBreak();
      if (c == 'restart') {
        _restart();
      } else if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _restart() => setState(() {
        world = _make();
        finished = false;
        paused = false;
      });

  Future<void> _pause() async {
    if (finished || _dialogOpen || !mounted) return;
    _dialogOpen = true;
    paused = true;
    await showPauseDialog(context, ctl,
        onResume: () => paused = false, onRestart: _restart, onQuit: () => Navigator.pop(context));
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = ctl.t;
    final title = switch (widget.mode) {
      PlayMode.campaign => '${t('level')} ${widget.level}',
      PlayMode.endless => t('endless'),
      PlayMode.daily => t('daily'),
    };
    final skin = gravitySkins.firstWhere((s) => s.id == ctl.save.selectedSkin, orElse: () => gravitySkins.first);
    return GameScaffold(
      ctl: ctl,
      title: title,
      finished: finished,
      onPause: _pause,
      stats: [
        Row(children: [const Icon(Icons.star_rounded, color: Colors.amber, size: 18), Text(' ${world.starsGot}')]),
        Text('${t('score')}: ${world.score}'),
        Text('${t('best')}: ${ctl.save.bestScore}'),
      ],
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (paused || finished) return;
          world.flip();
          ctl.audio.play('whoosh');
          ctl.audio.tap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: FlameSurface(onUpdate: _update, onDraw: (c, s) => _GsPainter(world, skin.color, ctl.info.color).paint(c, s)),
          ),
        ),
      ),
      bottom: Text(t('tapToFlip'), style: const TextStyle(color: Colors.white54)),
    );
  }
}

class _GsPainter extends CustomPainter {
  _GsPainter(this.w, this.ballColor, this.accent);
  final GsWorld w;
  final Color ballColor, accent;

  Path _star(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final o = c + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final bx = size.width * 0.25;
    double sx(double wx) => bx + (wx - w.x) * h;
    canvas.drawRect(Offset.zero & size,
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B2030), Color(0xFF10131D)]).createShader(Offset.zero & size));
    // moving grid for a sense of speed
    final grid = Paint()..color = Colors.white10;
    final off = (w.x * h) % 60;
    for (double gx = -off; gx < size.width; gx += 60) {
      canvas.drawLine(Offset(gx, 0), Offset(gx, h), grid);
    }
    // floor and ceiling rails
    final rail = Paint()..color = accent.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 4), rail);
    canvas.drawRect(Rect.fromLTWH(0, h - 4, size.width, 4), rail);
    // exit
    if (!w.level.endless) {
      final ex = sx(w.level.length);
      canvas.drawRect(Rect.fromLTWH(ex, 0, 10, h), Paint()..color = Colors.greenAccent.withValues(alpha: 0.8));
    }
    // checkpoints
    for (final c in w.level.checkpoints) {
      final cx = sx(c);
      if (cx < -20 || cx > size.width + 20) continue;
      final reached = w.x >= c;
      final p = Paint()
        ..color = (reached ? Colors.greenAccent : Colors.white38)
        ..strokeWidth = 3;
      canvas.drawLine(Offset(cx, h * 0.3), Offset(cx, h * 0.7), p);
      canvas.drawPath(Path()..moveTo(cx, h * 0.3)..lineTo(cx + 22, h * 0.36)..lineTo(cx, h * 0.42)..close(), p);
    }
    // pillars
    for (final o in w.level.obstacles) {
      final x1 = sx(o.x), x2 = sx(o.end);
      if (x2 < -10) continue;
      if (x1 > size.width + 10) break;
      final rect = o.top ? Rect.fromLTRB(x1, 0, x2, kObsH * h) : Rect.fromLTRB(x1, h - kObsH * h, x2, h);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rr, Paint()..shader = LinearGradient(colors: [const Color(0xFFFF5252), accent]).createShader(rect));
      canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white24);
    }
    // rotating platforms (pivot bars in the middle of the corridor)
    for (final p in w.level.platforms) {
      final px = sx(p.cx);
      if (px < -kPlatHalf * h || px > size.width + kPlatHalf * h) continue;
      final a = p.angleAt(w.x);
      final d = Offset(cos(a), sin(a)) * kPlatHalf * h;
      final c0 = Offset(px, h / 2);
      canvas.drawLine(c0 - d, c0 + d, Paint()..strokeWidth = 12..strokeCap = StrokeCap.round..color = Colors.purpleAccent);
      canvas.drawCircle(c0, 9, Paint()..color = Colors.white);
    }
    // gates (closed until their key is collected)
    for (var i = 0; i < w.level.gates.length; i++) {
      final g = w.level.gates[i];
      final x1 = sx(g.x), x2 = sx(g.end);
      if (x2 < -10) continue;
      if (x1 > size.width + 10) break;
      final open = w.keyTaken(g.keyIdx);
      final rect = Rect.fromLTRB(x1, 0, x2, h);
      canvas.drawRect(rect, Paint()..color = (open ? Colors.greenAccent : Colors.amber).withValues(alpha: open ? 0.15 : 0.75));
      if (!open) {
        for (double yy = 8; yy < h; yy += 22) {
          canvas.drawLine(Offset(x1, yy), Offset(x2, yy + 10), Paint()..color = Colors.black54..strokeWidth = 3);
        }
      }
    }
    // keys
    for (var i = 0; i < w.level.keys.length; i++) {
      final k = w.level.keys[i];
      final kx = sx(k.x);
      if (kx < -20) continue;
      if (kx > size.width + 20) break;
      if (w.keyTaken(i)) continue;
      final c0 = Offset(kx, k.top ? kR * h : h - kR * h);
      canvas.drawCircle(c0, kR * h * 0.75, Paint()..color = Colors.amber);
      canvas.drawCircle(c0 + Offset(-kR * h * 0.22, 0), kR * h * 0.2, Paint()..color = const Color(0xFF1B2030));
      canvas.drawRect(Rect.fromLTWH(c0.dx - kR * h * 0.05, c0.dy - 2, kR * h * 0.55, 4), Paint()..color = const Color(0xFF1B2030));
    }
    // stars
    for (final s in w.level.stars) {
      final sxp = sx(s.x);
      if (sxp < -10) continue;
      if (sxp > size.width + 10) break;
      canvas.drawPath(_star(Offset(sxp, s.top ? kR * h : h - kR * h), kR * h * 0.55), Paint()..color = Colors.amber);
    }
    // ball with glow
    final c = Offset(bx, w.y * h);
    canvas.drawCircle(c, kR * h * 1.9, Paint()..color = ballColor.withValues(alpha: 0.18));
    canvas.drawCircle(c, kR * h, Paint()..color = ballColor);
    canvas.drawCircle(c - Offset(kR * h * 0.3, kR * h * 0.3), kR * h * 0.25, Paint()..color = Colors.white54);
  }

  @override
  bool shouldRepaint(covariant _GsPainter old) => true;
}
