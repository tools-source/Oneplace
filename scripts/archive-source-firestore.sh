#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${1:-$ROOT_DIR/build/OnePlace.xcarchive}"
DERIVED_DATA_PATH="${2:-$ROOT_DIR/build/DerivedData}"
CLONED_PACKAGES_PATH="${3:-$ROOT_DIR/build/SourcePackages}"

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$DERIVED_DATA_PATH" "$CLONED_PACKAGES_PATH"

FIREBASE_SOURCE_FIRESTORE=1 xcodebuild archive \
  -scheme OnePlace \
  -project "$ROOT_DIR/OnePlace.xcodeproj" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$CLONED_PACKAGES_PATH"
