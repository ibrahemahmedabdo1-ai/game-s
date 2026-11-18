import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_info.dart';
import 'logic/drop.dart';

class DropScreen extends StatefulWidget {
  const DropScreen({super.key, required this.ctl, required this.mode, this.level = 1, this.round = 1, this.carry = 0});
  final ShellController ctl;
  final PlayMode mode;
  final int level, round, carry;
  @override
  State<DropScreen> createState() => _DropScreenState();
}

class _DropScreenState extends State<DropScreen> with WidgetsBindingObserver {
  late DropLevel lv;
  late List<int> config;
  DropSim? sim;
  double acc = 0;
  int moves = 0, bonusMoves = 0;
  bool paused = false, finished = false, _dialogOpen = false;
  int? hintPaddle;
  Size area = Size.zero;
  ShellController get ctl => widget.ctl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _load() {
    lv = switch (widget.mode) {
      PlayMode.campaign => DropLevel.campaign(widget.level),
      PlayMode.endless => DropLevel.endless(widget.round),
      PlayMode.daily => DropLevel.daily(dailySeed(DateTime.now())),
    };
    config = lv.startConfig;
    sim = null;
    moves = 0;
    bonusMoves = 0;
    hintPaddle = null;
    finished = false;
    paused = false;
  }

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

  int get movesLeft => lv.maxMoves + bonusMoves - moves;

  void _update(double dt) {
    final s = sim;
    if (s == null || paused || finished) return;
    acc += dt;
    while (acc >= DropSim.dt && !s.finished) {
      s.step();
      acc -= DropSim.dt;
    }
    if (s.finished) _done(s);
    setState(() {});
  }

  void _tapAt(Offset p) {
    if (sim != null || finished || paused) return;
    final scale = min(area.width / dW, area.height / dH);
    final ox = (area.width - dW * scale) / 2, oy = (area.height - dH * scale) / 2;
    final wx = (p.dx - ox) / scale, wy = (p.dy - oy) / scale;
    for (var i = 0; i < lv.paddles.length; i++) {
      final pd = lv.paddles[i];
      if ((pd.x - wx).abs() < 0.17 && (pd.y - wy).abs() < 0.12) {
        if (movesLeft <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${ctl.t('moves')}: 0')));
          return;
        }
        setState(() {
          config[i] = (config[i] + 1) % paddleAngles.length;
          moves++;
          hintPaddle = null;
        });
        ctl.audio.play('rotate');
        ctl.audio.tap();
        return;
      }
    }
  }

  void _release() {
    if (sim != null || finished) return;
    setState(() {
      sim = DropSim(lv, config);
      acc = 0;
    });
    ctl.audio.play('whoosh');
  }

  Future<void> _hint() async {
    if (sim != null || finished) return;
    if (ctl.save.hints <= 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(ctl.t('watchForHint')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(ctl.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(ctl.t('watchAd'))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      if (!await watchRewarded(context, ctl)) return;
      await ctl.commit(() => ctl.save.hints++);
    }
    await ctl.commit(() => ctl.save.hints--);
    for (var i = 0; i < config.length; i++) {
      if (config[i] != lv.bestConfig[i]) {
        setState(() => hintPaddle = i);
        return;
      }
    }
  }

  Future<void> _done(DropSim s) async {
    finished = true;
    final score = s.score * (100 + (s.perfect ? 100 : 0)) ~/ 10 * 10;
    final ratio = lv.bestScore == 0 ? 0.0 : s.score / lv.bestScore;
    final passed = s.score >= lv.passScore;
    if (!passed) {
      ctl.audio.play('lose');
      await _fail(s, score);
      return;
    }
    ctl.audio.play('win');
    final stars = ratio >= 0.95 ? 3 : (ratio >= 0.7 ? 2 : 1);
    if (widget.mode == PlayMode.campaign) {
      await ctl.finishLevel(widget.level, stars, score);
    } else {
      await ctl.commit(() {
        if (widget.mode == PlayMode.daily) {
          final today = dayKey(DateTime.now());
          if (ctl.save.lastDailyChallenge != today) {
            ctl.save.lastDailyChallenge = today;
            ctl.save.coins += 20;
          }
        }
        final total = score + widget.carry;
        if (total > ctl.save.bestScore) ctl.save.bestScore = total;
        ctl.save.roundsPlayed++;
        ctl.save.coins += stars * 3;
      });
    }
    if (!mounted) return;
    final lastLevel = widget.mode == PlayMode.campaign && widget.level >= ctl.info.levelCount;
    final c = await showResultDialog(context, ctl,
        title: s.perfect ? ctl.t('perfect') : ctl.t('levelComplete'),
        stars: stars,
        score: score + widget.carry,
        canNext: widget.mode != PlayMode.daily && !lastLevel,
        lines: ['${s.inGood}/${s.balls.length}']);
    if (!mounted) return;
    ctl.roundBreak();
    if (c == 'next') {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => DropScreen(ctl: ctl, mode: widget.mode, level: widget.level + 1, round: widget.round + 1, carry: score + widget.carry)));
    } else if (c == 'restart') {
      setState(_load);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _fail(DropSim s, int score) async {
    final c = await showResultDialog(context, ctl,
        title: ctl.t('gameOver'), score: score, offerContinue: true, lines: ['${s.inGood}/${s.balls.length}']);
    if (!mounted) return;
    if (c == 'continue') {
      if (await watchRewarded(context, ctl)) {
        setState(() {
          bonusMoves += 3;
          sim = null;
          finished = false;
        });
      } else {
        _fail(s, score);
      }
    } else {
      ctl.roundBreak();
      if (c == 'restart') {
        setState(_load);
      } else if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _pause() async {
    if (finished || _dialogOpen || !mounted) return;
    _dialogOpen = true;
    paused = true;
    await showPauseDialog(context, ctl,
        onResume: () => paused = false, onRestart: () => setState(_load), onQuit: () => Navigator.pop(context));
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = ctl.t;
    final title = switch (widget.mode) {
      PlayMode.campaign => '${t('level')} ${widget.level}',
      PlayMode.endless => '${t('endless')} #${widget.round}',
      PlayMode.daily => t('daily'),
    };
    final skin = dropSkins.firstWhere((k) => k.id == ctl.save.selectedSkin, orElse: () => dropSkins.first);
    return GameScaffold(
      ctl: ctl,
      title: title,
      finished: finished,
      onPause: _pause,
      stats: [
        Text('${t('moves')}: $movesLeft'),
        Text('${t('score')}: ${(sim?.score ?? 0)}/${lv.bestScore}'),
        Text('${t('best')}: ${ctl.save.bestScore}'),
      ],
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(builder: (_, box) {
            area = Size(box.maxWidth, box.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _tapAt(d.localPosition),
              child: FlameSurface(onUpdate: _update, onDraw: (c, s) => _DropPainter(lv, config, sim, skin.color, hintPaddle).paint(c, s)),
            );
          }),
        ),
      ),
      bottom: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilledButton.tonalIcon(onPressed: sim == null ? _hint : null, icon: const Icon(Icons.lightbulb_outline), label: Text('${t('hint')} · ${ctl.save.hints}')),
        const SizedBox(width: 12),
        FilledButton.icon(onPressed: sim == null ? _release : null, icon: const Icon(Icons.arrow_downward_rounded), label: Text(t('release'))),
      ]),
    );
  }
}

class _DropPainter extends CustomPainter {
  _DropPainter(this.lv, this.config, this.sim, this.ballColor, this.hint);
  final DropLevel lv;
  final List<int> config;
  final DropSim? sim;
  final Color ballColor;
  final int? hint;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / dW, size.height / dH);
    final ox = (size.width - dW * s) / 2, oy = (size.height - dH * s) / 2;
    Offset m(double x, double y) => Offset(ox + x * s, oy + y * s);
    final arena = Rect.fromLTWH(ox, oy, dW * s, dH * s);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF141826));
    canvas.drawRRect(RRect.fromRectAndRadius(arena, const Radius.circular(16)),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1D2238), Color(0xFF111423)]).createShader(arena));
    // spawner
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: m(0.5, 0.02), width: 0.3 * s, height: 0.05 * s), const Radius.circular(10)), Paint()..color = Colors.white24);
    // bins
    final bw = dW / lv.bins;
    for (var i = 0; i < lv.bins; i++) {
      final good = lv.mult[i] > 0;
      final r = Rect.fromLTRB(m(i * bw, binTop).dx + 2, m(0, binTop).dy, m((i + 1) * bw, 0).dx - 2, m(0, dH).dy - 2);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)),
          Paint()..color = good ? Color.lerp(const Color(0xFF3A3F66), const Color(0xFF7C4DFF), lv.mult[i] / 3)! : const Color(0xFF2A1B1B));
      final tp = TextPainter(
          text: TextSpan(text: good ? 'x${lv.mult[i]}' : '✕', style: TextStyle(color: good ? Colors.white : Colors.white38, fontSize: 0.06 * s, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
    }
    for (final p in lv.pegs) {
      canvas.drawCircle(m(p.x, p.y), pegR * s, Paint()..color = p.bumper ? Colors.orangeAccent : Colors.white38);
      if (p.bumper) canvas.drawCircle(m(p.x, p.y), pegR * s * 1.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.orangeAccent.withValues(alpha: 0.5));
    }
    for (var i = 0; i < lv.paddles.length; i++) {
      final p = lv.paddles[i];
      final a = paddleAngles[config[i]];
      final d = Offset(cos(a), sin(a)) * paddleHalf * s;
      final c = m(p.x, p.y);
      canvas.drawLine(c - d, c + d,
          Paint()
            ..strokeWidth = paddleThick * 2 * s + 4
            ..strokeCap = StrokeCap.round
            ..color = hint == i ? Colors.amber : const Color(0xFF7C4DFF));
      canvas.drawCircle(c, 5, Paint()..color = Colors.white);
    }
    final sm = sim;
    if (sm != null) {
      for (final b in sm.balls) {
        if (!b.active || (b.done && b.y > binTop + 0.1)) continue;
        canvas.drawCircle(m(b.x, b.y), ballR * s, Paint()..color = ballColor);
      }
    } else {
      for (final x in lv.spawnX) {
        canvas.drawCircle(m(x, 0.02), ballR * s * 0.8, Paint()..color = ballColor.withValues(alpha: 0.6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DropPainter old) => true;
}
