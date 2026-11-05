#!/usr/bin/env bash
# Build the web version (for tablets and phones) into build/web.
#
#   GODOT=/path/to/godot4.3 tools/build_web.sh
#
# Needs the Godot 4.3 export templates installed (Editor > Manage Export
# Templates). Uses the no-threads web template, so any static host works
# (GitHub Pages included): no special cross-origin headers are needed.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

# Make sure every asset has been imported once.
"$GODOT" --headless --editor --quit >/dev/null 2>&1 || true

# The Corrêa plates and portraits are JPEGs; store them as lossy WebP in the
# web build instead of lossless, which roughly quarters the download.
changed=0
for f in art/correa/*.jpg.import art/portraits/*.jpg.import; do
	if grep -q '^compress/mode=0' "$f"; then
		sed -i 's/^compress\/mode=0/compress\/mode=1/; s/^compress\/lossy_quality=.*/compress\/lossy_quality=0.8/' "$f"
		changed=1
	fi
done
if [ "$changed" = 1 ]; then
	"$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
fi

mkdir -p build/web
"$GODOT" --headless --export-release "Web" build/web/index.html
ls -la build/web
