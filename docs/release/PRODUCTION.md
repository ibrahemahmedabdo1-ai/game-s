# From this repo to a Google Play production release

Nothing below can be pre-generated for you; each item is one-time per game.

1. **Get CI green.** Push to GitHub, run *Android CI*. Fix any compile/analyze/test error it reports (expected on a first run of never-compiled code). Then run *Build APKs* and install `app-debug.apk` on a phone; play each game, test Arabic, back button, and that ads show **test** ads.
2. **Real package IDs.** Defaults are `com.casualstudio.<game>` (see `apps/*/app.properties`). If you want your own domain, change them **before** the first Play upload; they are permanent afterwards.
3. **AdMob.** Create an AdMob app per game (6 total) and 3 ad units each; add the 4 secrets per game (docs/admob/README.md). Release builds without them ship **with ads disabled** by design.
4. **Signing.** Create your upload key and add the 4 signing secrets (docs/release/SIGNING.md). Without them only debug APKs and an UNSIGNED AAB are produced.
5. **Privacy policy URL.** Fill the `[DATE]` and `[YOUR EMAIL]` in `docs/privacy/privacy_policy_<game>.md`, host it (GitHub Pages is fine), paste the URL in Play Console.
6. **Screenshots.** Capture real ones (see each `store_assets/<game>/screenshots/README.md`).
7. **Play Console.** Follow `docs/google_play/checklist_<game>.md`: listing text/graphics from `store_assets/<game>/`, Data safety, content rating, target audience (truthful; not child-directed by default), Ads = Yes.
8. **Release.** Tag `<game>-v1.0.0` (the tag must equal the pubspec version) -> *Release on tag* builds the signed AAB -> upload to **Internal testing** first, then promote.
9. **Updates.** Bump `version: x.y.z+N` (N always increasing), tag again. Same package ID + same upload key = same listing and preserved player saves.

Never click your own production ads; use test devices. Play review is not guaranteed by any checklist.
