# Setup, GitHub upload, builds, releases

## 1. Upload to GitHub
1. Unzip `casual-games-studio.zip`. You get one folder, `casual-games-studio/`.
2. Create an empty GitHub repository (no README).
3. In that folder: `git init && git add . && git commit -m "Initial import" && git branch -M main && git remote add origin <your-repo-url> && git push -u origin main`
   (or drag the folder contents into the GitHub web uploader; make sure the hidden `.github` folder is included).

## 2. Run the builds
- Pushing to `main` runs **Android CI** (analyze + tests) and **Build APKs**.
- Manual run: repo > **Actions** > pick a workflow > **Run workflow**.
- **Build APKs** always makes `app-debug.apk`. `app-release.apk` is made only if signing secrets exist; otherwise it is skipped and a note file says so.
- **Build AABs** (manual) makes `app-release.aab` if signed, otherwise `app-release-UNSIGNED.aab` (not uploadable to Play until signed).

## 3. Download
Actions > the run > **Artifacts** section at the bottom > `<game>-apks` / `<game>-aab` (zip). Install `app-debug.apk` on a phone to test.

## 4. First run will likely need fixes
No Flutter SDK was available when this was written, so nothing has been compiled. Open the failed step log, copy the error, and see `docs/troubleshooting/README.md`.

## 5. Go to production
See `docs/release/PRODUCTION.md` (AdMob IDs, signing key, privacy URL, screenshots).

## 6. Release an update (same Play listing)
1. Edit the game's `version:` in `apps/<game>/pubspec.yaml` (e.g. `1.0.1+2`; the number after `+` is versionCode and must always increase).
2. Update `CHANGELOG.md`.
3. `git tag color_reactor-v1.0.1 && git push origin color_reactor-v1.0.1` — the tag workflow builds and attaches APK/AAB to a GitHub Release.
4. Upload the signed AAB in Play Console > Production > Create new release. Keep the same package ID and the same upload key.
