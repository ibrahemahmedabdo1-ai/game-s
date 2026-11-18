# AdMob configuration
Development: nothing to do. Builds use Google's public demo IDs (`GoogleTestIds` in `packages/shared_ads/lib/admob_config.dart`).

Production, per game:
1. In AdMob, add the Android app, create 1 banner, 1 interstitial, 1 rewarded unit.
2. Add repository secrets with the game key suffix (color_reactor -> `COLOR_REACTOR`):
   `ADMOB_APP_ID_COLOR_REACTOR`, `ADMOB_BANNER_ID_COLOR_REACTOR`, `ADMOB_INTERSTITIAL_ID_COLOR_REACTOR`, `ADMOB_REWARDED_ID_COLOR_REACTOR`.
3. Release builds pass them as `--dart-define` and the app ID to the manifest.

Safety rules built in: if any production ID is missing/placeholder, or is a Google test ID, **ads stay disabled** (no silent test ads). Local test devices: `--dart-define=ADMOB_TEST_DEVICES=ID1,ID2`.

Behavior: banner only on menu and level select; interstitials only after a finished round (min 3 rounds, 120 s cooldown, 60 s launch grace, 8 per session); rewarded ads are always opt-in and the reward is given only after the SDK reports it earned. UMP consent is requested before the SDK initializes; a privacy-options entry appears in Settings when required.
Do not click your own production ads; use test devices.
