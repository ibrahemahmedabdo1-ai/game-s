import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_info.dart';
import 'logic/reactor.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.ctl, required this.mode, this.level = 1, this.endlessRound = 1, this.endlessScore = 0});
  final ShellController ctl;
  final PlayMode mode;
  final int level, endlessRound, endlessScore;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late ReactorLevel lv;
  late ReactorState st;
  int bonusMoves = 0;
  int? hint;
  bool finished = false, _dialogOpen = false;
  ShellController get ctl => widget.ctl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      ctl.audio.pauseMusic();
    } else if (s == AppLifecycleState.resumed) {
      ctl.audio.resumeMusic();
    }
  }

  void _load() {
    lv = switch (widget.mode) {
      PlayMode.campaign => ReactorLevel.campaign(widget.level),
      PlayMode.endless => ReactorLevel.endless(widget.endlessRound),
      PlayMode.daily => ReactorLevel.daily(dailySeed(DateTime.now())),
    };
    st = ReactorState(lv);
    bonusMoves = 0;
    hint = null;
    finished = false;
  }

  int get movesLeft => lv.maxMoves + bonusMoves - st.used;

  void _tap(int i) {
    if (finished) return;
    final penaltyBefore = st.penalty;
    final result = st.tap(i);
    switch (result) {
      case Tap.locked:
      case Tap.jammed:
        ctl.audio.buzz();
        return;
      case Tap.toggled:
        ctl.audio.play('power');
      case Tap.frozen:
        ctl.audio.play('click');
      case Tap.rotated:
        ctl.audio.play('rotate');
    }
    ctl.audio.tap();
    if (st.penalty > penaltyBefore) {
      ctl.audio.play('hurt');
      ctl.audio.buzz();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(duration: const Duration(milliseconds: 900), content: Text(ctl.t('wrongRoute'))));
    }
    setState(() => hint = null);
    if (st.solved) {
      _win();
    } else if (movesLeft <= 0) {
      _lose();
    }
  }

  Future<void> _win() async {
    finished = true;
    ctl.audio.play('win');
    final stars = starsFor(moves: st.used, par: lv.par);
    final score = scoreFor(level: widget.mode == PlayMode.campaign ? widget.level : widget.endlessRound + 20, moves: st.used, par: lv.par);
    var total = score;
    if (widget.mode == PlayMode.campaign) {
      await ctl.finishLevel(widget.level, stars, score);
    } else if (widget.mode == PlayMode.endless) {
      total = widget.endlessScore + score;
      await ctl.commit(() {
        if (total > ctl.save.bestScore) ctl.save.bestScore = total;
        ctl.save.roundsPlayed++;
      });
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
    final choice = await showResultDialog(context, ctl,
        title: ctl.t('levelComplete'),
        stars: stars,
        score: total,
        canNext: !last && widget.mode != PlayMode.daily,
        lines: ['${ctl.t('moves')}: ${st.used}']);
    if (!mounted) return;
    ctl.roundBreak();
    if (choice == 'next') {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => GameScreen(
                  ctl: ctl, mode: widget.mode, level: widget.level + 1, endlessRound: widget.endlessRound + 1, endlessScore: total)));
    } else if (choice == 'restart') {
      setState(_load);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _lose() async {
    finished = true;
    ctl.audio.play('lose');
    ctl.audio.buzz();
    if (widget.mode == PlayMode.endless) {
      await ctl.commit(() {
        if (widget.endlessScore > ctl.save.bestScore) ctl.save.bestScore = widget.endlessScore;
        ctl.save.roundsPlayed++;
      });
    }
    if (!mounted) return;
    final choice = await showResultDialog(context, ctl, title: ctl.t('gameOver'), score: widget.endlessScore, offerContinue: true);
    if (!mounted) return;
    if (choice == 'continue') {
      if (await watchRewarded(context, ctl)) {
        setState(() {
          bonusMoves += 5;
          finished = false;
        });
      } else if (mounted) {
        _lose();
      }
    } else {
      ctl.roundBreak();
      if (choice == 'restart') {
        setState(_load);
      } else if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _useHint() async {
    if (finished) return;
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
    setState(() => hint = st.hint());
  }

  Future<void> _pause() async {
    if (finished || _dialogOpen || !mounted) return;
    _dialogOpen = true;
    await showPauseDialog(context, ctl, onResume: () {}, onRestart: () => setState(_load), onQuit: () => Navigator.pop(context));
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = ctl.t;
    final title = switch (widget.mode) {
      PlayMode.campaign => '${t('level')} ${widget.level}',
      PlayMode.endless => '${t('endless')} #${widget.endlessRound}',
      PlayMode.daily => t('daily'),
    };
    return GameScaffold(
      ctl: ctl,
      title: title,
      finished: finished,
      onPause: _pause,
      actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: t('restart'), onPressed: () => setState(_load))],
      stats: [
        Text('${t('movesLeft')}: $movesLeft'),
        if (widget.mode == PlayMode.endless) Text('${t('score')}: ${widget.endlessScore}'),
        Text('${t('best')}: ${ctl.save.bestScore}'),
      ],
      body: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(builder: (_, box) {
              final cell = box.maxWidth / lv.w;
              return GestureDetector(
                onTapUp: (d) {
                  final c = (d.localPosition.dx / cell).floor();
                  final r = (d.localPosition.dy / cell).floor();
                  if (c >= 0 && c < lv.w && r >= 0 && r < lv.h) _tap(r * lv.w + c);
                },
                child: CustomPaint(size: Size(box.maxWidth, box.maxWidth), painter: _BoardPainter(lv, st, hint)),
              );
            }),
          ),
        ),
      ),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (lv.switchCell != null || lv.tracks.isNotEmpty || lv.capacity.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(ctl.t('legend'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        FilledButton.tonalIcon(onPressed: _useHint, icon: const Icon(Icons.lightbulb_outline), label: Text('${t('hint')} · ${ctl.save.hints}')),
      ]),
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.lv, this.st, this.hint);
  final ReactorLevel lv;
  final ReactorState st;
  final int? hint;

  void _glyph(Canvas c, IconData icon, Offset center, double size, Color color) {
    final tp = TextPainter(
        text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / lv.w;
    final masks = st.masks;
    final frozen = st.frozen;
    final flow = <int, int>{};
    final reached = <bool>[];
    for (var i = 0; i < lv.colors; i++) {
      final tr = lv.trace(masks, i, switchOn: st.switchOn);
      reached.add(tr.reached);
      for (final c in tr.cells) {
        flow[c] = i;
      }
    }
    for (var r = 0; r < lv.h; r++) {
      for (var c = 0; c < lv.w; c++) {
        final idx = r * lv.w + c;
        final rect = Rect.fromLTWH(c * cell + 2, r * cell + 2, cell - 4, cell - 4);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
        final isGate = lv.gateCells.contains(idx);
        canvas.drawRRect(rr, Paint()..color = const Color(0xFF1E2230));
        if (isGate) {
          canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = st.switchOn ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.deepOrangeAccent);
        }
        if (hint == idx) canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.amber);
        final ctr = rect.center;
        if (idx == lv.switchCell) {
          // toggle switch
          final pill = RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: cell * 0.6, height: cell * 0.3), Radius.circular(cell * 0.15));
          canvas.drawRRect(pill, Paint()..color = st.switchOn ? Colors.greenAccent : Colors.white24);
          canvas.drawCircle(Offset(ctr.dx + (st.switchOn ? 1 : -1) * cell * 0.15, ctr.dy), cell * 0.12, Paint()..color = Colors.white);
          continue;
        }
        final p = Paint()
          ..strokeWidth = cell * 0.2
          ..strokeCap = StrokeCap.round
          ..color = flow.containsKey(idx) ? reactorColors[flow[idx]!] : Colors.white30;
        for (final d in allDirs) {
          if (masks[idx] & d == 0) continue;
          canvas.drawLine(ctr, ctr + Offset(dCol(d) * cell / 2, dRow(d) * cell / 2), p);
        }
        canvas.drawCircle(ctr, cell * 0.11, p);
        if (isGate && !st.switchOn) {
          canvas.drawLine(rect.topLeft + const Offset(8, 8), rect.bottomRight - const Offset(8, 8), Paint()..color = Colors.deepOrangeAccent.withValues(alpha: 0.7)..strokeWidth = 3);
        }
        if (lv.locked.contains(idx)) _glyph(canvas, Icons.lock, Offset(rect.right - cell * 0.18, rect.top + cell * 0.18), cell * 0.26, Colors.white70);
        final cap = lv.capacity[idx];
        if (cap != null) {
          final left = st.remainingCapacity(idx);
          final tp = TextPainter(
              text: TextSpan(text: '$left', style: TextStyle(fontSize: cell * 0.24, fontWeight: FontWeight.bold, color: left == 0 ? Colors.redAccent : Colors.amberAccent)),
              textDirection: TextDirection.ltr)
            ..layout();
          tp.paint(canvas, Offset(rect.left + 6, rect.bottom - tp.height - 4));
        }
        if (frozen.contains(idx)) {
          canvas.drawRRect(rr, Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.35));
          _glyph(canvas, Icons.ac_unit, ctr, cell * 0.5, Colors.white);
        }
      }
    }
    for (var i = 0; i < lv.colors; i++) {
      final col = reactorColors[i];
      canvas.drawCircle(Offset(cell * 0.12, lv.sourceRows[i] * cell + cell / 2), cell * 0.12, Paint()..color = col);
      canvas.drawCircle(
          Offset(size.width - cell * 0.12, lv.targetRows[i] * cell + cell / 2),
          cell * 0.13,
          Paint()
            ..color = col
            ..style = reached[i] ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
