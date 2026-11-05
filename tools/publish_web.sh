#!/usr/bin/env bash
# Build the web version and publish it to the gh-pages branch (GitHub Pages).
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build_web.sh
REMOTE="$(git remote get-url origin)"
TMP="$(mktemp -d)"
cp -r build/web/. "$TMP/"
touch "$TMP/.nojekyll"
cd "$TMP"
git init -q -b gh-pages
git add -A
git commit -q -m "Web build $(date -u +%Y-%m-%d)"
git push -f "$REMOTE" gh-pages
echo "Published. GitHub Pages serves it from the gh-pages branch."
