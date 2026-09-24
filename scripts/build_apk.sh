#!/bin/bash
set -e

# Auto-bumps the patch version + build number in pubspec.yaml, syncs
# lib/constants/version.dart, builds the release APK, and renames the
# output to catchify-v<version>.apk.
#
# Usage: bash scripts/build_apk.sh [flavor]
#   flavor defaults to "github" (use "fdroid" for the F-Droid flavor)

cd "$(dirname "$0")/.."

if [ -f "tools/env.sh" ]; then
  # shellcheck source=/dev/null
  source tools/env.sh
fi

PUBSPEC="pubspec.yaml"
FLAVOR="${1:-github}"

current=$(grep -oE '^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' "$PUBSPEC" | sed 's/^version: //')
if [ -z "$current" ]; then
  echo "Unable to read a semantic version from $PUBSPEC"
  exit 1
fi
version="${current%+*}"
build="${current##*+}"

major=$(echo "$version" | cut -d. -f1)
minor=$(echo "$version" | cut -d. -f2)
patch=$(echo "$version" | cut -d. -f3)

new_patch=$((patch + 1))
new_build=$((build + 1))
new_version="${major}.${minor}.${new_patch}"

original_pubspec=$(mktemp)
cp "$PUBSPEC" "$original_pubspec"
cleanup() {
  if [ "${1:-0}" -ne 0 ]; then
    cp "$original_pubspec" "$PUBSPEC"
    bash update.sh
  fi
  rm -f "$original_pubspec"
}
trap 'cleanup $?' EXIT

sed -i "s/^version: .*/version: ${new_version}+${new_build} # run update.sh after changing the version/" "$PUBSPEC"

bash update.sh

SPLIT_ARG=""
if [[ "$*" == *"--split-per-abi"* ]]; then
  SPLIT_ARG="--split-per-abi"
  echo "Enabling --split-per-abi for ~20MB lightweight APKs..."
fi

echo "Building catchify v${new_version}+${new_build} (flavor: ${FLAVOR})..."
flutter build apk --release --flavor "$FLAVOR" $SPLIT_ARG

if [ -n "$SPLIT_ARG" ]; then
  echo "Built split-per-abi APKs under build/app/outputs/flutter-apk/"
else
  apk_src=$(find "build/app/outputs" -type f -name "app-${FLAVOR}-release.apk" -print -quit)
  if [ -z "$apk_src" ]; then
    echo "Unable to find the ${FLAVOR} release APK under build/app/outputs"
    exit 1
  fi
  apk_dest="build/app/outputs/flutter-apk/catchify-v${new_version}.apk"
  mkdir -p "$(dirname "$apk_dest")"
  cp "$apk_src" "$apk_dest"

  echo "Built ${apk_dest}"
fi
