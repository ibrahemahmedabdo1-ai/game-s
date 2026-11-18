import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import 'game_info.dart';
import 'logic/merge.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key, required this.ctl, required this.mode, this.level = 1, this.layoutIndex = 0});
  final ShellController ctl;
  final PlayMode mode;
  final int level, layoutIndex;
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  late MergeState st;
  bool finished = false, _dialogOpen = false;
  Size area = Size.zero;
  ShellController get ctl => widget.ctl;

  @override
  void initState() {
    super.initState();
    st = _make();
  }

  MergeState _make() {
    final layout = widget.mode == PlayMode.campaign ? layoutForStage(widget.level) : layouts[widget.layoutIndex % layouts.length];
    return switch (widget.mode) {
      PlayMode.campaign => MergeState(layout: layout, seed: 4200 + widget.level * 13, difficulty: widget.level, goal: MergeState.goalFor(widget.level)),
      PlayMode.endless => MergeState(layout: layout, seed: DateTime.now().millisecondsSinceEpoch & 0xFFFFFF),
      PlayMode.daily => MergeState(layout: layout, seed: dailySeed(DateTime.now()), difficulty: 10),
    };
  }

  void _tap(Offset p) {
    if (finished) return;
    final s = min(area.width, area.height);
    final ox = (area.width - s) / 2, oy = (area.height - s) / 2;
    final cell = s / st.n;
    final c = ((p.dx - ox) / cell).floor(), r = ((p.dy - oy) / cell).floor();
    if (c < 0 || r < 0 || c >= st.n || r >= st.n) return;
    final before = st.score;
    if (st.place(r * st.n + c)) {
      ctl.audio.tap();
      ctl.audio.play(st.score > before ? 'pop' : 'click');
      setState(() {});
      if (st.reachedGoal && widget.mode == PlayMode.campaign) {
        _win();
      } else if (st.over) {
        _lose();
      }
    }
  }

  Future<void> _win() async {
    finished = true;
    final e = st.empties;
    final stars = e >= 8 ? 3 : (e >= 4 ? 2 : 1);
    await ctl.finishLevel(widget.level, stars, st.score);
    if (!mounted) return;
    final lastLevel = widget.level >= ctl.info.levelCount;
    final c = await showResultDialog(context, ctl, title: ctl.t('levelComplete'), stars: stars, score: st.score, canNext: !lastLevel);
    if (!mounted) return;
    ctl.roundBreak();
    if (c == 'next') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MergeScreen(ctl: ctl, mode: widget.mode, level: widget.level + 1, layoutIndex: (widget.level + 1) % layouts.length)));
    } else if (c == 'restart') {
      setState(() {
        st = _make();
        finished = false;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _lose() async {
    finished = true;
    ctl.audio.play('lose');
    await ctl.commit(() {
      if (st.score > ctl.save.bestScore) ctl.save.bestScore = st.score;
      ctl.save.roundsPlayed++;
      ctl.save.coins += st.score ~/ 200;
      if (widget.mode == PlayMode.daily) {
        final today = dayKey(DateTime.now());
        if (ctl.save.lastDailyChallenge != today) {
          ctl.save.lastDailyChallenge = today;
          ctl.save.coins += 20;
        }
      }
    });
    if (!mounted) return;
    final c = await showResultDialog(context, ctl, title: ctl.t('gameOver'), score: st.score, offerContinue: true, lines: ['${ctl.t('combo')}: x${st.bestChain}']);
    if (!mounted) return;
    if (c == 'continue') {
      if (await watchRewarded(context, ctl)) {
        st.rescue();
        setState(() => finished = false);
      } else {
        _lose();
      }
    } else {
      ctl.roundBreak();
      if (c == 'restart') {
        setState(() {
          st = _make();
          finished = false;
        });
      } else if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _undo() async {
    if (finished) return;
    if (st.undosLeft <= 0) {
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
      st.grantUndo();
    }
    setState(() => st.undo());
  }

  Future<void> _pause() async {
    if (finished || _dialogOpen || !mounted) return;
    _dialogOpen = true;
    await showPauseDialog(context, ctl,
        onResume: () {},
        onRestart: () => setState(() => st = _make()),
        onQuit: () => Navigator.pop(context));
    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = ctl.t;
    final title = switch (widget.mode) {
      PlayMode.campaign => '${t('stage')} ${widget.level}',
      PlayMode.endless => t('endless'),
      PlayMode.daily => t('daily'),
    };
    final next = st.upcoming(2);
    return GameScaffold(
      ctl: ctl,
      title: title,
      finished: finished,
      onPause: _pause,
      stats: [
        Text('${t('score')}: ${st.score}'),
        if (st.goal > 0) Text('${t('goal')}: ${st.goal}') else Text('${t('best')}: ${ctl.save.bestScore}'),
      ],
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _PieceChip(piece: st.current, big: true),
            const SizedBox(width: 18),
            for (final p in next) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Opacity(opacity: 0.55, child: _PieceChip(piece: p))),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: LayoutBuilder(builder: (_, box) {
              area = Size(box.maxWidth, box.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tap(d.localPosition),
                child: CustomPaint(size: Size.infinite, painter: _BoardPainter(st)),
              );
            }),
          ),
        ),
      ]),
      bottom: FilledButton.tonalIcon(onPressed: _undo, icon: const Icon(Icons.undo_rounded), label: Text('${t('undo')} · ${st.undosLeft}')),
    );
  }
}

Path polygon(Offset c, double r, int sides, [double rot = -pi / 2]) {
  final p = Path();
  for (var i = 0; i < sides; i++) {
    final a = rot + i * 2 * pi / sides;
    final o = c + Offset(cos(a) * r, sin(a) * r);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

void drawPiece(Canvas canvas, Offset c, double r, Piece p) {
  if (p.kind == Kind.bomb) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF263238));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.orangeAccent);
    canvas.drawCircle(c + Offset(r * 0.5, -r * 0.5), r * 0.18, Paint()..color = Colors.orange);
    return;
  }
  if (p.kind == Kind.wild) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.5;
      final a = -pi / 2 + i * pi / 5;
      final o = c + Offset(cos(a) * rr, sin(a) * rr);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..shader = const SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.purple, Colors.red]).createShader(Rect.fromCircle(center: c, radius: r)));
    return;
  }
  drawLevel(canvas, c, r, p.level);
}

void drawLevel(Canvas canvas, Offset c, double r, int level) {
  final col = mergeColors[(level - 1).clamp(0, mergeColors.length - 1)];
  final sides = min(level + 2, 8);
  canvas.drawPath(polygon(c, r, sides), Paint()..color = col);
  canvas.drawPath(polygon(c, r, sides), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white54);
  final tp = TextPainter(
      text: TextSpan(text: '$level', style: TextStyle(color: Colors.black87, fontSize: r * 0.9, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
}

class _PieceChip extends StatelessWidget {
  const _PieceChip({required this.piece, this.big = false});
  final Piece piece;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final s = big ? 64.0 : 40.0;
    return SizedBox(width: s, height: s, child: CustomPaint(painter: _ChipPainter(piece)));
  }
}

class _ChipPainter extends CustomPainter {
  _ChipPainter(this.p);
  final Piece p;
  @override
  void paint(Canvas canvas, Size size) => drawPiece(canvas, size.center(Offset.zero), size.width / 2 - 2, p);
  @override
  bool shouldRepaint(covariant _ChipPainter old) => old.p != p;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.st);
  final MergeState st;
  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    final ox = (size.width - s) / 2, oy = (size.height - s) / 2;
    final cell = s / st.n;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox, oy, s, s), const Radius.circular(18)), Paint()..color = const Color(0xFF1A1F30));
    for (var i = 0; i < st.cells.length; i++) {
      final r = i ~/ st.n, c = i % st.n;
      final rect = Rect.fromLTWH(ox + c * cell + 3, oy + r * cell + 3, cell - 6, cell - 6);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      final v = st.cells[i];
      final bonus = st.layout.bonus.contains(i);
      canvas.drawRRect(rr, Paint()..color = v == -1 ? const Color(0xFF4A4F5C) : (bonus ? const Color(0xFF3B3520) : const Color(0xFF242A40)));
      if (bonus) canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.amber.withValues(alpha: 0.6));
      if (v > 0) drawLevel(canvas, rect.center, cell * 0.36, v);
      if (v == -1) {
        canvas.drawLine(rect.topLeft + const Offset(10, 10), rect.bottomRight - const Offset(10, 10), Paint()..color = Colors.white24..strokeWidth = 3);
        canvas.drawLine(rect.topRight + const Offset(-10, 10), rect.bottomLeft + const Offset(10, -10), Paint()..color = Colors.white24..strokeWidth = 3);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
