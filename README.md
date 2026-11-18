# Casual Games Studio

Six Android apps in one monorepo (Flutter): **Color Reactor, Gravity Switch, Shape Eater, Perfect Drop, Color Merge Lab** and the aggregator **Mini Puzzle Arcade**. Offline-first, Arabic/English (RTL), ethical AdMob monetization with UMP consent, GitHub Actions builds.

## Honest status
| Item | State |
|---|---|
| Mechanics added in the second pass: Color Reactor (capacity pipes, switch+gates, moving ice hazards, wrong-route penalty), Gravity Switch (rotating platforms, key+gate puzzles), Shape Eater and Color Merge Lab now 100 stages, Flame engine for the three real-time games, daily missions in all games, richer synthesized audio | Written |
| 5 games + arcade: gameplay, menus, settings, save, daily reward, achievements, tutorial, pause/back handling, rewarded continue/hints, interstitial rules | Written |
| Unit + widget tests for logic, levels, ads policy, storage, localization, navigation | Written |
| Level generators checked (Python re-implementation) for solvability: Color Reactor, Gravity Switch, Perfect Drop | Checked outside Dart |
| **Compiled / analyzed / test-run with the Flutter SDK** | **NOT yet.** No Flutter SDK was available when this was written. The first **Android CI** run will show any compile error; fix those before shipping. |
| Real AdMob IDs, signing key, hosted privacy URL, real screenshots | **You must supply** (cannot be generated). See `docs/release/PRODUCTION.md` |

## Layout
`apps/` (6 apps, each with `app.properties` = permanent package ID) · `packages/` (shared_storage, shared_localization, shared_ads, shared_audio, shared_game_core, shared_ui) · `android_templates/` + `scripts/prepare_android.sh` (generates the Android project at build time: target SDK 36, signing, adaptive icons, AdMob placeholder) · `store_assets/<game>/` (icons, feature graphic, EN/AR listing) · `docs/` · `.github/workflows/`.

Start here: `UPLOAD_GUIDE_AR.md` (Arabic quick guide), then `docs/release/SETUP.md` and `docs/release/PRODUCTION.md`.
