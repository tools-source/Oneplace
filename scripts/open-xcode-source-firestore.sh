#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if pgrep -x Xcode >/dev/null 2>&1; then
  echo "Quit Xcode first so FIREBASE_SOURCE_FIRESTORE is applied when it opens."
  exit 1
fi

open --env FIREBASE_SOURCE_FIRESTORE=1 "$ROOT_DIR/OnePlace.xcodeproj"
