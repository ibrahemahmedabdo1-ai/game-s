#!/usr/bin/env bash
# Packs the repository (without build output or secrets) into casual-games-studio.zip
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/.."
zip -r "casual-games-studio.zip" "$(basename "$ROOT")" \
  -x '*/build/*' '*/.dart_tool/*' '*/release/*' '*.jks' '*/key.properties' '*/.git/*' '*/android/local.properties'
unzip -tq casual-games-studio.zip
