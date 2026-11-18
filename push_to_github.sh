#!/usr/bin/env bash
set -e
command -v git >/dev/null || { echo "Install git first"; exit 1; }
read -r -p "Empty GitHub repo URL (https://github.com/USER/REPO.git): " REPO
[ -d .git ] || git init
git add -A
git commit -m "Initial import"
git branch -M main
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO"
git push -u origin main
echo "Done. Open the repo on GitHub > Actions."
