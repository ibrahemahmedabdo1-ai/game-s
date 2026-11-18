# Troubleshooting
- **`flutter pub get` version conflict**: dependency ranges (caret) were not verified against today's Flutter. Relax/bump the failing package in the relevant `pubspec.yaml`; once it resolves, commit `pubspec.lock` for reproducible builds.
- **Gradle: "compileSdk 36 requires AGP >= 8.9.x"**: update `com.android.application` version in the generated `android/settings.gradle.kts`, or use a newer Flutter stable. Fix in `scripts/prepare_android.sh` (add a sed step).
- **`kotlinOptions` unresolved**: newer AGP/Kotlin; replace with `kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }` in `android_templates/build.gradle.kts.tmpl`.
- **Release APK skipped**: signing secrets missing, by design.
- **No ads in a release build**: production IDs missing/placeholder, by design (see docs/admob).
- **Analyzer errors in shared_ui**: first run; paste the output to get them fixed.
- **`flame` version / API**: shared_ui depends on `flame: ^1.21.0` and only uses `FlameGame`, `GameWidget`, `update`, `render`, `backgroundColor`. If the resolved version changes any of these, edit `FlameSurface` at the bottom of `packages/shared_ui/lib/shared_ui.dart`.
