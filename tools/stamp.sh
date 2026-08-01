#!/usr/bin/env bash
# stamp.sh — realm-sigil version stamp for a static site (house convention).
#
# Wraps realm-sigil's static/build.sh, which writes version.json and injects the
# <meta name="realm-version"> tag into index.html, then copies that document to
# api/version so the standard endpoint exists on a host with no server.
#
#   ./tools/stamp.sh
#
# Why api/version is a plain extensionless FILE and not a directory: GitHub Pages
# resolves /api/version to it directly and returns the bytes. A directory would need
# an index.html and would answer /api/version/ instead, which is not the path
# status.realm.watch checks. The checker json-parses the body and does not look at
# the content type.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGIL="${REALM_SIGIL_DIR:-$HOME/Projects/realm-sigil}"

if [ ! -x "$SIGIL/static/build.sh" ]; then
  echo "stamp: realm-sigil not found at $SIGIL — clone https://github.com/jphein/realm-sigil" >&2
  echo "       or set REALM_SIGIL_DIR to point at it." >&2
  exit 1
fi

"$SIGIL/static/build.sh" \
  --name        bard.realm.watch \
  --description "A 260K-parameter transformer writing stories on a \$3 microcontroller" \
  --realm       fantasy \
  --repo        https://github.com/jphein/bard.realm.watch \
  --html        index.html \
  --dir         "$ROOT"

mkdir -p "$ROOT/api"
cp "$ROOT/version.json" "$ROOT/api/version"

echo "stamp: $(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$ROOT/version.json")"
echo "       version.json + api/version written"
