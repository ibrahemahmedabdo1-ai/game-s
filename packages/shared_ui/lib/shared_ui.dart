import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_ads/shared_ads.dart';
import 'package:shared_audio/shared_audio.dart';
import 'package:shared_game_core/shared_game_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_storage/shared_storage.dart';

export 'package:shared_ads/shared_ads.dart';
export 'package:shared_audio/shared_audio.dart';
export 'package:shared_game_core/shared_game_core.dart';
export 'package:shared_localization/shared_localization.dart';
export 'package:shared_storage/shared_storage.dart';

/// Per-game identity used by the shared screens.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.color,
    required this.levelCount,
    required this.tutorialEn,
    required this.tutorialAr,
    this.extraStrings = const {},
  });
  final String id, titleEn, titleAr;
  final Color color;
  final int levelCount;
  final List<String> tutorialEn, tutorialAr;
  final Map<String, Map<String, String>> extraStrings;
}

/// App-wide state: save data, language, audio, ads.
class ShellController extends ChangeNotifier {
  ShellController._(this.info, this.store, this.save, this.audio, this.ads);
  final GameInfo info;
  final SaveStore store;
  final GameSave save;
  final AudioManager audio;
  final AdsService ads;

  static Future<ShellController> create(GameInfo info, {bool test = false, AdsService? sharedAds}) async {
    final store = await SaveStore.open(info.id);
    final save = store.load();
    final audio = AudioManager(sound: save.sound, music: save.music, haptics: save.haptics);
    await audio.init(silent: test);
    final ads = sharedAds ?? AdsService(AdmobConfig.fromEnvironment());
    final c = ShellController._(info, store, save, audio, ads);
    // Ads/consent initialise in the background; the game never waits on them.
    if (!test) {
      if (sharedAds == null) ads.initialize().then((_) => c.notifyListeners());
      audio.syncMusic();
    }
    return c;
  }

  Loc get loc => Loc(save.language, extra: info.extraStrings);
  String get title => save.language == 'ar' ? info.titleAr : info.titleEn;
  String t(String k) => loc.t(k);

  Future<void> commit([void Function()? change]) async {
    change?.call();
    audio.sound = save.sound;
    audio.music = save.music;
    audio.haptics = save.haptics;
    await store.save(save);
    notifyListeners();
    audio.syncMusic();
  }

  /// Natural break between rounds: the ONLY place an interstitial may appear.
  void roundBreak() {
    save.reportEvent('round', 1, DateTime.now());
    store.save(save);
    ads.roundCompleted(onShowing: audio.pauseMusic, onClosed: audio.resumeMusic);
  }

  /// Persist finished level, check achievements, trigger interstitial rules.
  Future<List<String>> finishLevel(int level, int stars, int score) async {
    final unlocked = <String>[];
    await commit(() {
      save.completeLevel(level, stars, score);
      save.roundsPlayed++;
      save.coins += 5 * stars;
      save.reportEvent('win', 1, DateTime.now());
      save.reportEvent('stars', stars, DateTime.now());
      unlocked.addAll(checkAchievements(save));
    });
    return unlocked;
  }
}

class StudioApp extends StatelessWidget {
  const StudioApp({super.key, required this.ctl, required this.home});
  final ShellController ctl;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctl,
      builder: (_, __) => MaterialApp(
        title: ctl.title,
        debugShowCheckedModeBanner: false,
        locale: Locale(ctl.save.language),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: ctl.info.color,
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
          dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF1B1F2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
        ),
        builder: (context, child) => StudioBackground(color: ctl.info.color, child: child ?? const SizedBox()),
        home: home,
      ),
    );
  }
}

// ---------------------------------------------------------------- widgets

class BigButton extends StatelessWidget {
  const BigButton(this.label, this.onTap, {super.key, this.icon, this.color});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 260,
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: onTap,
            icon: Icon(icon ?? Icons.play_arrow_rounded),
            label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.ctl, required this.onDone});
  final ShellController ctl;
  final VoidCallback onDone;
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.ctl.info.color;
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.4)])),
                child: const Icon(Icons.bubble_chart_rounded, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(widget.ctl.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Casual Games Studio', style: TextStyle(color: Colors.white54)),
            ]),
          ),
        ),
      ),
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({
    super.key,
    required this.ctl,
    required this.onContinue,
    required this.onLevels,
    required this.onEndless,
    required this.onDaily,
    this.extra = const [],
  });
  final ShellController ctl;
  final VoidCallback onContinue, onLevels, onEndless, onDaily;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctl,
      builder: (context, _) {
        final t = ctl.t;
        final now = DateTime.now();
        final canClaim = ctl.save.canClaimDaily(now);
        return Scaffold(
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.monetization_on, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text('${ctl.save.coins}'),
                  const Spacer(),
                  Text('${t('best')}: ${ctl.save.bestScore}'),
                ]),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(ctl.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: ctl.info.color)),
                      const SizedBox(height: 24),
                      BigButton(t('continue') + ' · ${t('level')} ${ctl.save.currentLevel.clamp(1, ctl.info.levelCount)}',
                          () {
                        ctl.audio.tap();
                        onContinue();
                      }),
                      BigButton(t('levels'), onLevels, icon: Icons.grid_view_rounded),
                      BigButton(t('endless'), onEndless, icon: Icons.all_inclusive),
                      BigButton(t('daily'), onDaily, icon: Icons.today_rounded),
                      BigButton(canClaim ? t('dailyReward') : t('claimed'), canClaim
                          ? () async {
                              final n = now;
                              int got = 0;
                              await ctl.commit(() => got = ctl.save.claimDaily(n));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text('+$got ${t('coins')}')));
                              }
                            }
                          : null, icon: Icons.card_giftcard, color: Colors.amber.shade800),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            tooltip: t('tutorial'),
                            icon: const Icon(Icons.help_outline),
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => TutorialScreen(ctl: ctl)))),
                        IconButton(
                            tooltip: t('achievements'),
                            icon: const Icon(Icons.emoji_events_outlined),
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => AchievementsScreen(ctl: ctl)))),
                        IconButton(
                            tooltip: t('missions'),
                            icon: const Icon(Icons.assignment_turned_in_outlined),
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => MissionsScreen(ctl: ctl)))),
                        ...extra,
                        IconButton(
                            tooltip: t('settings'),
                            icon: const Icon(Icons.settings),
                            onPressed: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => SettingsScreen(ctl: ctl)))),
                      ]),
                    ]),
                  ),
                ),
              ),
              AdaptiveBanner(ads: ctl.ads),
            ]),
          ),
        );
      },
    );
  }
}

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key, required this.ctl, required this.onPick});
  final ShellController ctl;
  final void Function(int level) onPick;
  @override
  Widget build(BuildContext context) {
    final s = ctl.save;
    return Scaffold(
      appBar: AppBar(title: Text(ctl.t('levels'))),
      body: Column(children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: ctl.info.levelCount,
            itemBuilder: (_, i) {
              final lvl = i + 1;
              final unlocked = lvl <= s.currentLevel;
              final st = s.stars[lvl] ?? 0;
              return Material(
                color: unlocked ? ctl.info.color.withValues(alpha: 0.25) : Colors.white10,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: unlocked ? () => onPick(lvl) : null,
                  child: Center(
                    child: unlocked
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('$lvl', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              for (var k = 1; k <= 3; k++)
                                Icon(Icons.star, size: 11, color: k <= st ? Colors.amber : Colors.white24)
                            ]),
                          ])
                        : const Icon(Icons.lock, size: 18, color: Colors.white38),
                  ),
                ),
              );
            },
          ),
        ),
        AdaptiveBanner(ads: ctl.ads),
      ]),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.ctl});
  final ShellController ctl;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctl,
      builder: (context, _) {
        final t = ctl.t;
        final s = ctl.save;
        return Scaffold(
          appBar: AppBar(title: Text(t('settings'))),
          body: ListView(children: [
            SwitchListTile(title: Text(t('sound')), value: s.sound, onChanged: (v) => ctl.commit(() => s.sound = v)),
            SwitchListTile(title: Text(t('music')), value: s.music, onChanged: (v) => ctl.commit(() => s.music = v)),
            SwitchListTile(title: Text(t('haptics')), value: s.haptics, onChanged: (v) => ctl.commit(() => s.haptics = v)),
            ListTile(
              title: Text(t('language')),
              trailing: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'en', label: Text(Loc('en').t('english'))),
                  ButtonSegment(value: 'ar', label: Text(Loc('ar').t('arabic'))),
                ],
                selected: {s.language},
                onSelectionChanged: (v) => ctl.commit(() => s.language = v.first),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(t('privacy')),
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(t('privacy')),
                  content: SingleChildScrollView(child: Text('${t('privacyBody')}\n\n${t('adsNote')}')),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t('close')))],
                ),
              ),
            ),
            if (ctl.ads.privacyOptionsRequired)
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(t('privacyOptions')),
                onTap: ctl.ads.showPrivacyOptions,
              ),
          ]),
        );
      },
    );
  }
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.ctl});
  final ShellController ctl;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(ctl.t('achievements'))),
        body: ListView(children: [
          for (final a in standardAchievements)
            ListTile(
              leading: Icon(ctl.save.achievements.contains(a.id) ? Icons.emoji_events : Icons.lock_outline,
                  color: ctl.save.achievements.contains(a.id) ? Colors.amber : Colors.white38),
              title: Text(ctl.t('ach_${a.id}')),
              subtitle: ctl.save.achievements.contains(a.id) ? Text(ctl.t('unlocked')) : null,
            ),
        ]),
      );
}

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.ctl, this.onDone});
  final ShellController ctl;
  final VoidCallback? onDone;
  @override
  State<TutorialScreen> createState() => _TutorialState();
}

class _TutorialState extends State<TutorialScreen> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final pages = ctl.save.language == 'ar' ? ctl.info.tutorialAr : ctl.info.tutorialEn;
    final last = page == pages.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(ctl.t('tutorial'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Expanded(
                child: Center(
                    child: Text(pages[page], textAlign: TextAlign.center, style: const TextStyle(fontSize: 22)))),
            Text('${page + 1}/${pages.length}'),
            const SizedBox(height: 12),
            BigButton(last ? ctl.t('done') : ctl.t('next'), () async {
              if (!last) {
                setState(() => page++);
              } else {
                await ctl.commit(() => ctl.save.tutorialSeen = true);
                if (!context.mounted) return;
                widget.onDone != null ? widget.onDone!() : Navigator.pop(context);
              }
            }, icon: Icons.arrow_forward),
          ]),
        ),
      ),
    );
  }
}

/// Pause dialog: resume / restart / quit.
Future<void> showPauseDialog(BuildContext context, ShellController ctl,
    {required VoidCallback onResume, required VoidCallback onRestart, required VoidCallback onQuit}) {
  final t = ctl.t;
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(t('pause')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          BigButton(t('resume'), () {
            Navigator.pop(context);
            onResume();
          }),
          BigButton(t('restart'), () {
            Navigator.pop(context);
            onRestart();
          }, icon: Icons.refresh),
          BigButton(t('quit'), () {
            Navigator.pop(context);
            onQuit();
          }, icon: Icons.home, color: Colors.blueGrey),
        ]),
      ),
    ),
  );
}


// ------------------------------------------------------------ shared kit

enum PlayMode { campaign, endless, daily }

class StudioBackground extends StatelessWidget {
  const StudioBackground({super.key, required this.color, required this.child});
  final Color color;
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.9),
            radius: 1.3,
            colors: [Color.lerp(const Color(0xFF12141C), color, 0.28)!, const Color(0xFF0C0E15)],
          ),
        ),
        child: child,
      );
}

class SkinDef {
  const SkinDef(this.id, this.nameEn, this.nameAr, this.color, this.cost);
  final String id, nameEn, nameAr;
  final Color color;
  final int cost;
}

class SkinsScreen extends StatelessWidget {
  const SkinsScreen({super.key, required this.ctl, required this.skins});
  final ShellController ctl;
  final List<SkinDef> skins;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ctl,
        builder: (context, _) {
          final s = ctl.save;
          final ar = s.language == 'ar';
          return Scaffold(
            appBar: AppBar(title: Text(ctl.t('skins')), actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text('${s.coins}'),
                ]),
              )
            ]),
            body: ListView(children: [
              for (final k in skins)
                ListTile(
                  leading: CircleAvatar(backgroundColor: k.color, radius: 18),
                  title: Text(ar ? k.nameAr : k.nameEn),
                  trailing: s.unlockedSkins.contains(k.id)
                      ? (s.selectedSkin == k.id
                          ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                          : TextButton(
                              onPressed: () => ctl.commit(() => s.selectedSkin = k.id),
                              child: Text(ctl.t('select'))))
                      : FilledButton.tonal(
                          onPressed: s.coins >= k.cost
                              ? () => ctl.commit(() {
                                    s.coins -= k.cost;
                                    s.unlockedSkins.add(k.id);
                                    s.selectedSkin = k.id;
                                  })
                              : null,
                          child: Text('${k.cost}')),
                ),
            ]),
          );
        },
      );
}

/// Splash -> menu -> level select / tutorial -> game. Used by every game.
class StandardRoot extends StatefulWidget {
  const StandardRoot({super.key, required this.ctl, required this.gameBuilder, this.extraMenu});
  final ShellController ctl;
  final Widget Function(PlayMode mode, int level) gameBuilder;
  final List<Widget> Function(BuildContext context)? extraMenu;
  @override
  State<StandardRoot> createState() => _StandardRootState();
}

class _StandardRootState extends State<StandardRoot> {
  bool splash = true;
  ShellController get ctl => widget.ctl;

  void _start(BuildContext context, PlayMode mode, {int level = 1}) {
    void go() => Navigator.push(context, MaterialPageRoute(builder: (_) => widget.gameBuilder(mode, level)));
    if (!ctl.save.tutorialSeen) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TutorialScreen(
                  ctl: ctl,
                  onDone: () {
                    Navigator.pop(context);
                    go();
                  })));
    } else {
      go();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (splash) return SplashScreen(ctl: ctl, onDone: () => setState(() => splash = false));
    return MainMenuScreen(
      ctl: ctl,
      extra: widget.extraMenu?.call(context) ?? const [],
      onContinue: () => _start(context, PlayMode.campaign, level: ctl.save.currentLevel.clamp(1, ctl.info.levelCount)),
      onLevels: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LevelSelectScreen(
                  ctl: ctl,
                  onPick: (l) {
                    Navigator.pop(context);
                    _start(context, PlayMode.campaign, level: l);
                  }))),
      onEndless: () => _start(context, PlayMode.endless),
      onDaily: () => _start(context, PlayMode.daily),
    );
  }
}

/// Result dialog. Returns 'next', 'menu', 'restart' or 'continue' (user chose the optional rewarded video).
Future<String?> showResultDialog(BuildContext context, ShellController ctl,
    {required String title, int? stars, required int score, bool canNext = false, bool offerContinue = false, List<String> lines = const []}) {
  final t = ctl.t;
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (stars != null)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 1; k <= 3; k++) Icon(Icons.star_rounded, size: 40, color: k <= stars ? Colors.amber : Colors.white24)
            ]),
          const SizedBox(height: 8),
          Text('${t('score')}: $score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('${t('best')}: ${ctl.save.bestScore}'),
          for (final l in lines) Text(l),
          if (offerContinue) ...[const SizedBox(height: 12), Text(t('watchForContinue'), textAlign: TextAlign.center)],
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 4,
        actions: [
          if (offerContinue)
            FilledButton.icon(
                icon: const Icon(Icons.ondemand_video),
                onPressed: () => Navigator.pop(context, 'continue'),
                label: Text(t('watchAd'))),
          if (canNext) FilledButton(onPressed: () => Navigator.pop(context, 'next'), child: Text(t('next'))),
          TextButton(onPressed: () => Navigator.pop(context, 'restart'), child: Text(t('restart'))),
          TextButton(onPressed: () => Navigator.pop(context, 'menu'), child: Text(t('quit'))),
        ],
      ),
    ),
  );
}

/// Opt-in rewarded video. True only if the SDK confirmed the reward.
Future<bool> watchRewarded(BuildContext context, ShellController ctl) async {
  final ok = await ctl.ads.showRewarded(onShowing: ctl.audio.pauseMusic, onClosed: ctl.audio.resumeMusic);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ctl.t('rewardFailed'))));
  }
  return ok;
}

/// Shared in-game scaffold: pause button, back-button -> pause dialog, stats row.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.ctl,
    required this.title,
    required this.body,
    required this.onPause,
    this.stats = const [],
    this.actions = const [],
    this.bottom,
    this.finished = false,
  });
  final ShellController ctl;
  final String title;
  final Widget body;
  final Future<void> Function() onPause;
  final List<Widget> stats, actions;
  final Widget? bottom;
  final bool finished;
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !finished) onPause();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(icon: const Icon(Icons.pause_circle_outline), onPressed: finished ? null : onPause),
            actions: actions,
          ),
          body: SafeArea(
            child: Column(children: [
              if (stats.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: stats),
                ),
              Expanded(child: body),
              if (bottom != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: bottom),
            ]),
          ),
        ),
      );
}


class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key, required this.ctl});
  final ShellController ctl;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ctl,
        builder: (context, _) {
          final now = DateTime.now();
          final missions = ctl.save.todaysMissions(now);
          return Scaffold(
            appBar: AppBar(title: Text(ctl.t('missions'))),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              for (final m in missions)
                Card(
                  color: Colors.white10,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(ctl.loc.tf('m_${m.event}', {'n': m.target}), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: (ctl.save.missionProgress[m.id] ?? 0) / m.target, minHeight: 8, borderRadius: BorderRadius.circular(6)),
                          const SizedBox(height: 4),
                          Text('${ctl.save.missionProgress[m.id] ?? 0}/${m.target}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      if (ctl.save.missionClaimed.contains(m.id))
                        const Icon(Icons.check_circle, color: Colors.greenAccent)
                      else
                        FilledButton(
                          onPressed: ctl.save.missionDone(m) ? () => ctl.commit(() => ctl.save.claimMission(m, now)) : null,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.monetization_on, size: 16), Text(' ${m.reward}')]),
                        ),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );
}

class _CanvasGame extends FlameGame {
  _CanvasGame(this.onUpdate, this.onDraw);
  final void Function(double dt) onUpdate;
  final void Function(Canvas canvas, Size size) onDraw;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  void update(double dt) {
    super.update(dt);
    onUpdate(dt.clamp(0.0, 0.033).toDouble());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x > 0 && size.y > 0) onDraw(canvas, Size(size.x, size.y));
  }
}

/// Runs a game loop on the Flame engine: [onUpdate] each frame, then [onDraw] on its canvas.
class FlameSurface extends StatefulWidget {
  const FlameSurface({super.key, required this.onUpdate, required this.onDraw});
  final void Function(double dt) onUpdate;
  final void Function(Canvas canvas, Size size) onDraw;
  @override
  State<FlameSurface> createState() => _FlameSurfaceState();
}

class _FlameSurfaceState extends State<FlameSurface> {
  late final _CanvasGame _game = _CanvasGame((dt) => widget.onUpdate(dt), (c, s) => widget.onDraw(c, s));
  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}
