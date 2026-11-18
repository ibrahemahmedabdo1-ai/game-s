#!/usr/bin/env bash
# Local build of every game (needs Flutter + Android SDK). Usage: scripts/build_all.sh [apk-debug|apk-release|aab]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-apk-debug}"
for a in "$ROOT"/apps/*/; do "$ROOT/scripts/ci_build.sh" "$(basename "$a")" "$MODE"; done
echo "Outputs in $ROOT/release/"
