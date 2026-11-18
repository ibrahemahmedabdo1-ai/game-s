# Google Play checklist: Perfect Drop: Ball Puzzle
Package ID: `com.casualstudio.perfectdrop` (permanent). Display name in app: Perfect Drop.

## Before creating the release
- [ ] Create the app in Play Console with this exact package ID, default language English, add Arabic
- [ ] Real AdMob app + 3 ad units created; secrets `ADMOB_*_PERFECT_DROP` added (docs/admob/README.md)
- [ ] Signing secrets added; AAB built signed (`app-release.aab`, not `-UNSIGNED`)
- [ ] Privacy policy `docs/privacy/privacy_policy_perfect_drop.md` hosted at a public URL and entered in Play Console
- [ ] Store listing text from `store_assets/perfect_drop/listing/`; icon 512 `icons/play_store_icon_512.png`; feature graphic `feature_graphic_1024x500.png`
- [ ] Real phone screenshots captured (see `store_assets/perfect_drop/screenshots/README.md`)
- [ ] App content: Ads = Yes; Data safety per `docs/privacy/DATA_SAFETY.md`; content rating questionnaire; target audience chosen truthfully (default: 13+/general, not child-directed)
- [ ] Government/news/health/financial declarations answered "No" (none apply)
- [ ] Tested on a real device with a test ad device ID: consent form, banner on menus only, interstitial after rounds only, rewarded optional
- [ ] Internal testing track first, then closed/production (new personal accounts may need a closed test with testers before production; check current Play requirements)
