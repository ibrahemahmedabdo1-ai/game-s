# Architecture
- Each game = Flutter app depending on `shared_ui` (which re-exports storage, localization, ads, audio, core).
- `ShellController` owns save data, language, audio and ads and rebuilds the app on change.
- Game logic is pure Dart (e.g. `apps/color_reactor/lib/logic/reactor.dart`) so it is unit tested without a device.
- Levels are produced by seeded generators (same level number => same puzzle). Campaign = hand-tuned difficulty curve driven by level number; Daily = date seed; Endless = round counter.
- Android folders are generated at build time by `scripts/prepare_android.sh` and not committed.
- Real-time games (Gravity Switch, Shape Eater, Perfect Drop) run their loop on the **Flame** engine through `FlameSurface` in shared_ui (a thin `FlameGame` that forwards update/render); the tap-based puzzles (Color Reactor, Color Merge Lab) use plain Flutter widgets. Physics and rules are small hand-written pure-Dart classes, unit tested.
- Daily missions: `GameSave.todaysMissions` draws 3 missions per day (rounds / levels / stars); progress is reported from `ShellController.finishLevel` and `roundBreak`.
- `StandardRoot`, `GameScaffold`, `showResultDialog`, `watchRewarded`, `SkinsScreen` in shared_ui give every game identical menus, pause/back handling and ad placement.
- Mini Puzzle Arcade depends on the five game packages (path dependencies), reuses their roots, and shares one AdsService with them.
