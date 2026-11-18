import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_info.dart';
import 'logic/eater.dart';

class EaterScreen extends StatefulWidget {
  const EaterScreen({super.key, required this.ctl, required this.mode, this.level = 1});
  final ShellController ctl;
  final PlayMode mode;
  final int level;
  @override
  State<EaterScreen> createState() => _EaterScreenState();
}

class _EaterScreenState extends State<EaterScreen> with WidgetsBindingObserver {
  late SeWorld world;
  bool paused = false, finished = false, _dialogOpen = false;
  Size area = Size.zero;
  ShellController get ctl => widget.ctl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    world = _make();
  }

  SeWorld _make() => switch (widget.mode) {
        PlayMode.campaign => SeWorld(difficulty: widget.level, seed: 900 + widget.level * 17),
        PlayMode.endless => SeWorld(difficulty: 4, seed: DateTime.now().millisecondsSinceEpoch & 0xFFFFFF, endless: true),
        PlayMode.daily => SeWorld(difficulty: 12, seed: dailySeed(DateTime.now()), endless: true),
      };

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
    world.step(dt);
    for (final ev in world.events) {
      switch (ev) {
        case 'eat':
        case 'chain':
          ctl.audio.play('pop');
        case 'hurt':
          ctl.audio.play('hurt');
          ctl.audio.buzz();
        case 'power':
          ctl.audio.play('power');
        case 'shape':
          ctl.audio.play('coin');
      }
    }
    world.events.clear();
    if (world.stageDone) {
      _win();
    } else if (world.over) {
      _lose();
    }
    setState(() {});
  }

  Future<void> _win() async {
    finished = true;
    ctl.audio.play('win');
    final stars = world.starRating;
    await ctl.finishLevel(widget.level, stars, world.score);
    if (!mounted) return;
    final lastLevel = widget.level >= ctl.info.levelCount;
    final c = await showResultDialog(context, ctl,
        title: ctl.t('levelComplete'), stars: stars, score: world.score, canNext: !lastLevel);
    if (!mounted) return;
    ctl.roundBreak();
    if (c == 'next') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => EaterScreen(ctl: ctl, mode: widget.mode, level: widget.level + 1)));
    } else if (c == 'restart') {
      _restart();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _lose() async {
    finished = true;
    ctl.audio.play('lose');
    await ctl.commit(() {
      if (world.score > ctl.save.bestScore) ctl.save.bestScore = world.score;
      ctl.save.roundsPlayed++;
      if (widget.mode == PlayMode.daily) {
        final today = dayKey(DateTime.now());
        if (ctl.save.lastDailyChallenge != today) {
          ctl.save.lastDailyChallenge = today;
          ctl.save.coins += 20;
        }
      }
      ctl.save.coins += world.score ~/ 100;
    });
    if (!mounted) return;
    final c = await showResultDialog(context, ctl,
        title: ctl.t('gameOver'),
        score: world.score,
        offerContinue: true,
        lines: ['${ctl.t('combo')}: x${world.bestCombo}']);
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

  void _drag(Offset p) {
    final s = min(area.width / arenaW, area.height / arenaH);
    final ox = (area.width - arenaW * s) / 2, oy = (area.height - arenaH * s) / 2;
    world.tx = ((p.dx - ox) / s).clamp(0, arenaW).toDouble();
    world.ty = ((p.dy - oy) / s - 0.12).clamp(0, arenaH).toDouble(); // finger offset so the shape stays visible
  }

  @override
  Widget build(BuildContext context) {
    final t = ctl.t;
    final title = switch (widget.mode) {
      PlayMode.campaign => '${t('stage')} ${widget.level}',
      PlayMode.endless => t('endless'),
      PlayMode.daily => t('daily'),
    };
    final pal = sePalettes[ctl.save.selectedSkin] ?? sePalettes['default']!;
    return GameScaffold(
      ctl: ctl,
      title: title,
      finished: finished,
      onPause: _pause,
      stats: [
        Row(children: [for (var i = 0; i < 3; i++) Icon(Icons.favorite, size: 18, color: i < world.lives ? Colors.redAccent : Colors.white24)]),
        if (world.combo > 1) Text('${t('combo')} x${world.multiplier}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        Text('${t('score')}: ${world.score}'),
        if (widget.mode == PlayMode.campaign) Text('${world.eatenStage}/${world.target}') else Text('${t('best')}: ${ctl.save.bestScore}'),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(builder: (_, box) {
            area = Size(box.maxWidth, box.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _drag(d.localPosition),
              onPanUpdate: (d) => _drag(d.localPosition),
              onTapDown: (d) => _drag(d.localPosition),
              child: FlameSurface(onUpdate: _update, onDraw: (c, s) => _EaterPainter(world, pal).paint(c, s)),
            );
          }),
        ),
      ),
    );
  }
}

class _EaterPainter extends CustomPainter {
  _EaterPainter(this.w, this.pal);
  final SeWorld w;
  final List<Color> pal;

  void _shape(Canvas c, Shape s, Offset o, double r, Paint p) {
    switch (s) {
      case Shape.circle:
        c.drawCircle(o, r, p);
      case Shape.square:
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: r * 1.8, height: r * 1.8), Radius.circular(r * 0.25)), p);
      case Shape.triangle:
        c.drawPath(
            Path()
              ..moveTo(o.dx, o.dy - r * 1.1)
              ..lineTo(o.dx + r * 1.05, o.dy + r * 0.8)
              ..lineTo(o.dx - r * 1.05, o.dy + r * 0.8)
              ..close(),
            p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / arenaW, size.height / arenaH);
    final ox = (size.width - arenaW * s) / 2, oy = (size.height - arenaH * s) / 2;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF141826));
    final arena = Rect.fromLTWH(ox, oy, arenaW * s, arenaH * s);
    canvas.drawRRect(RRect.fromRectAndRadius(arena, const Radius.circular(16)),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1C2236), Color(0xFF121523)]).createShader(arena));
    Offset m(double x, double y) => Offset(ox + x * s, oy + y * s);
    for (final b in w.bars) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(m(b.x, b.y - Bar.half).dx, m(b.x, b.y - Bar.half).dy, m(b.x + b.w, b.y + Bar.half).dx, m(b.x + b.w, b.y + Bar.half).dy), const Radius.circular(6)),
          Paint()..color = Colors.redAccent.withValues(alpha: 0.85));
    }
    for (final it in w.items) {
      final o = m(it.x, it.y);
      if (it.power != null) {
        final icon = switch (it.power!) { Power.shield => Icons.shield, Power.slow => Icons.hourglass_top, Power.magnet => Icons.adjust };
        canvas.drawCircle(o, it.r * s * 1.1, Paint()..color = Colors.white.withValues(alpha: 0.15));
        final tp = TextPainter(
            text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontSize: it.r * s * 1.7, fontFamily: icon.fontFamily, color: Colors.white)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
      } else {
        _shape(canvas, it.shape, o, it.r * s, Paint()..color = pal[it.shape.index]);
      }
    }
    final po = m(w.px, w.py);
    final blink = w.invuln > 0 && (w.invuln * 10).floor().isEven;
    if (!blink) {
      if (w.shield > 0) {
        canvas.drawCircle(po, w.radius * s * 1.45, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.lightBlueAccent);
      }
      if (w.magnet > 0) {
        canvas.drawCircle(po, 0.45 * s, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.redAccent.withValues(alpha: 0.35));
      }
      _shape(canvas, w.shape, po, w.radius * s, Paint()..color = pal[w.shape.index]);
      _shape(canvas, w.shape, po, w.radius * s, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white);
    }
    if (w.slow > 0) {
      canvas.drawRect(arena, Paint()..color = Colors.deepPurpleAccent.withValues(alpha: 0.08));
    }
  }

  @override
  bool shouldRepaint(covariant _EaterPainter old) => true;
}
