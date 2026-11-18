#!/usr/bin/env bash
# Static analysis + tests for every package and app. Also checks package IDs are unique.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for d in "$ROOT"/packages/* "$ROOT"/apps/*; do
  [ -f "$d/pubspec.yaml" ] || continue
  echo "=== $(basename "$d") ==="
  (cd "$d" && flutter pub get && flutter analyze && { [ ! -d test ] || flutter test; })
done
ids=$(grep -h '^APP_ID=' "$ROOT"/apps/*/app.properties | sort)
dups=$(echo "$ids" | uniq -d)
[ -z "$dups" ] || { echo "Duplicate package IDs: $dups"; exit 1; }
for a in "$ROOT"/apps/*/; do
  g=$(basename "$a"); [ -f "$ROOT/store_assets/$g/icons/ic_launcher_xxxhdpi.png" ] || { echo "Missing icon for $g"; exit 1; }
done
echo "All validations passed."
