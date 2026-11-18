import 'package:colormergelab/game_info.dart' as merge;
import 'package:colormergelab/root.dart' as merge_root;
import 'package:colorreactor/game_info.dart' as reactor;
import 'package:colorreactor/root.dart' as reactor_root;
import 'package:flutter/material.dart';
import 'package:gravityswitch/game_info.dart' as gravity;
import 'package:gravityswitch/root.dart' as gravity_root;
import 'package:perfectdrop/game_info.dart' as drop;
import 'package:perfectdrop/root.dart' as drop_root;
import 'package:shapeeater/game_info.dart' as eater;
import 'package:shapeeater/root.dart' as eater_root;
import 'package:shared_ui/shared_ui.dart';

class _Entry {
  const _Entry(this.info, this.icon, this.build);
  final GameInfo info;
  final IconData icon;
  final Widget Function(ShellController) build;
}

final _games = <_Entry>[
  _Entry(reactor.colorReactorInfo, Icons.hub_rounded, reactor_root.colorReactorRoot),
  _Entry(gravity.gravitySwitchInfo, Icons.swap_vert_circle_rounded, gravity_root.gravitySwitchRoot),
  _Entry(eater.shapeEaterInfo, Icons.pentagon_rounded, eater_root.shapeEaterRoot),
  _Entry(drop.perfectDropInfo, Icons.south_rounded, drop_root.perfectDropRoot),
  _Entry(merge.colorMergeInfo, Icons.science_rounded, merge_root.colorMergeRoot),
];

Widget arcadeRoot(ShellController ctl) => _ArcadeRoot(ctl: ctl);

class _ArcadeRoot extends StatefulWidget {
  const _ArcadeRoot({required this.ctl});
  final ShellController ctl;
  @override
  State<_ArcadeRoot> createState() => _ArcadeRootState();
}

class _ArcadeRootState extends State<_ArcadeRoot> {
  bool splash = true, opening = false;
  ShellController get ctl => widget.ctl;

  Future<void> _open(_Entry e) async {
    if (opening) return;
    setState(() => opening = true);
    // Each game keeps its own save; the arcade shares its ad service and language.
    final gc = await ShellController.create(e.info, sharedAds: ctl.ads);
    await gc.commit(() => gc.save.language = ctl.save.language);
    if (!mounted) return;
    setState(() => opening = false);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _GameHost(ctl: gc, entry: e)));
    if (gc.save.language != ctl.save.language) {
      await ctl.commit(() => ctl.save.language = gc.save.language);
    }
    await gc.audio.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (splash) return SplashScreen(ctl: ctl, onDone: () => setState(() => splash = false));
    return ListenableBuilder(
      listenable: ctl,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(ctl.title),
          actions: [
            IconButton(
                tooltip: ctl.t('settings'),
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(ctl: ctl)))),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(12), child: Text(ctl.t('arcadeTitle'), style: const TextStyle(fontSize: 18, color: Colors.white70))),
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                for (final e in _games)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      borderRadius: BorderRadius.circular(22),
                      color: e.info.color.withValues(alpha: 0.22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: opening ? null : () => _open(e),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(children: [
                            CircleAvatar(radius: 28, backgroundColor: e.info.color, child: Icon(e.icon, color: Colors.white, size: 30)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(ctl.save.language == 'ar' ? e.info.titleAr : e.info.titleEn,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            ),
                            const Icon(Icons.play_circle_fill_rounded, size: 34),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            AdaptiveBanner(ads: ctl.ads),
          ]),
        ),
      ),
    );
  }
}

/// Hosts a game inside the arcade: its own controller drives language/RTL for that subtree.
class _GameHost extends StatelessWidget {
  const _GameHost({required this.ctl, required this.entry});
  final ShellController ctl;
  final _Entry entry;
  @override
  Widget build(BuildContext context) {
    final outer = Navigator.of(context);
    return ListenableBuilder(
      listenable: ctl,
      builder: (context, _) => Directionality(
        textDirection: ctl.loc.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
              // Back on the game's own menu returns to the arcade hub.
              builder: (_) => PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop) outer.pop();
                  },
                  child: entry.build(ctl))),
        ),
      ),
    );
  }
}
