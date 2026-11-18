# Google Play checklist (per game; no approval is guaranteed)
- [ ] Package ID unique and final (see `apps/<game>/app.properties`)
- [ ] Signed AAB uploaded; Play App Signing enabled
- [ ] Target API meets the current Play requirement (template uses 36; recheck at submission)
- [ ] Privacy policy hosted at a public URL (template: docs/privacy/PRIVACY_POLICY_TEMPLATE.md) and linked in Play Console
- [ ] Data safety form completed (see docs/privacy/DATA_SAFETY.md)
- [ ] Ads declaration: "Yes, contains ads"
- [ ] Content rating questionnaire answered truthfully (IARC)
- [ ] Target audience: choose truthfully. Default assumption here is **not** child-directed (13+/general). If you target children, the Families policy applies: use only Families-certified ad setup, no personalized ads, and re-review the whole app.
- [ ] Real AdMob IDs set; app-ads.txt if you host a developer website
- [ ] Store listing text/graphics reviewed (store_assets/<game>/)
- [ ] Tested on a real device: offline start, Arabic RTL, back button, ad flows with test device
## Permissions audit
INTERNET, ACCESS_NETWORK_STATE (ads), VIBRATE (haptics setting). No location, contacts, camera, microphone, phone.
## Third-party SDKs
Google Mobile Ads SDK (AdMob) + User Messaging Platform; Flutter engine; audioplayers; shared_preferences.
