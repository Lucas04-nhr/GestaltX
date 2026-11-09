#!/usr/bin/env bash
# Build GestaltX and package an ad-hoc signed IPA with the entitlements of the
# app and its share extension embedded, so that SideStore and AltStore can see
# the App Group and register it when they re-sign the app.
#
# Usage: .github/scripts/build-ipa.sh [output-dir]   (default: build/ipa)
#
# Set SOURCE_DIR to build a checkout other than this repository (CI builds an
# upstream tag checked out next to it). Set BUILD_DATE (YYYY-MM-DD) to write it
# to GestaltX/BuildDate.txt, which the About page shows.
#
# CFBundleVersion of the app and its share extension:
# - BUILD_NUMBER (a positive integer) is used as is.
# - Otherwise BUILD_INCREMENT (a positive integer) is added to the project's
#   CURRENT_PROJECT_VERSION, e.g. 11100017 + 7 = 11100024. CI passes its run
#   number, so every build is higher than the project's own build number and
#   than every earlier CI build.
# - With neither, the project's CURRENT_PROJECT_VERSION is kept.
# The version users see stays the marketing version, shown on the About page as
# "1.1.0 (11100024)". AltStore and SideStore offer an update when the build
# number changes. With BUILD_NUMBER or BUILD_INCREMENT the IPA is named
# GestaltX_<version>+<build>.ipa, which the AltStore source reads as
# buildVersion; otherwise it is named GestaltX_<version>.ipa.
#
# In GitHub Actions, `version`, `build` and `ipa` are written to GITHUB_OUTPUT.
set -euo pipefail

root="$(cd "${SOURCE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../..}" && pwd)"
out="$(mkdir -p "${1:-$root/build/ipa}" && cd "${1:-$root/build/ipa}" && pwd)"
cd "$root"

# Every target must share one marketing version
version="$(sed -n 's/^[[:space:]]*MARKETING_VERSION = \(.*\);/\1/p' GestaltX.xcodeproj/project.pbxproj | sort -u)"
if [[ -z "$version" || "$(wc -l <<< "$version")" -ne 1 ]]; then
  echo "Error: expected one MARKETING_VERSION, found: ${version:-none}" >&2
  exit 1
fi
project_build="$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION = \(.*\);/\1/p' GestaltX.xcodeproj/project.pbxproj | sort -u)"
if [[ ! "$project_build" =~ ^[0-9]+$ ]]; then
  echo "Error: expected one numeric CURRENT_PROJECT_VERSION, found: ${project_build:-none}" >&2
  exit 1
fi
build_settings=()
numbered=false
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]{0,8}$ ]]; then
    echo "Error: BUILD_NUMBER must be a positive integer, got: $BUILD_NUMBER" >&2
    exit 1
  fi
  build="$BUILD_NUMBER"
  numbered=true
elif [[ -n "${BUILD_INCREMENT:-}" ]]; then
  if [[ ! "$BUILD_INCREMENT" =~ ^[1-9][0-9]{0,8}$ ]]; then
    echo "Error: BUILD_INCREMENT must be a positive integer, got: $BUILD_INCREMENT" >&2
    exit 1
  fi
  build="$((project_build + BUILD_INCREMENT))"
  numbered=true
else
  build="$project_build"
fi
if $numbered; then
  # A command-line setting applies to every target, so the extension matches the app
  build_settings+=("CURRENT_PROJECT_VERSION=$build")
fi
echo "==> Building GestaltX $version ($build)"

if [[ -n "${BUILD_DATE:-}" ]]; then
  printf '%s' "$BUILD_DATE" > GestaltX/BuildDate.txt
fi

# Building the app target also builds the embedded share extension
xcodebuild -quiet \
  -project GestaltX.xcodeproj \
  -target GestaltX \
  -configuration Release \
  -sdk iphoneos \
  SYMROOT="$root/build" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  ${build_settings[@]+"${build_settings[@]}"} \
  build

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload" "$out"
cp -R "$root/build/Release-iphoneos/GestaltX.app" "$stage/Payload/"
app="$stage/Payload/GestaltX.app"
appex="$app/PlugIns/GestaltXShare.appex"

echo "==> Signing with entitlements"
# Sign nested code from the inside out: frameworks and dylibs, then the
# extension, then the app
while IFS= read -r -d '' item; do
  codesign -f -s - "$item"
done < <(find "$app" \( -name '*.framework' -o -name '*.dylib' \) -print0)

# Older versions have no share extension
bundles=()
if [[ -d "$appex" ]]; then
  codesign -f -s - --entitlements ShareExtension/GestaltXShare.entitlements "$appex"
  bundles+=("$appex")
fi
codesign -f -s - --entitlements GestaltX/GestaltX.entitlements "$app"
bundles+=("$app")

for bundle in "${bundles[@]}"; do
  if ! codesign -d --entitlements - --xml "$bundle" 2>/dev/null | grep -q 'com.apple.security.application-groups'; then
    echo "Error: ${bundle#"$stage/"} has no App Group entitlement after signing" >&2
    exit 1
  fi
done

if $numbered; then
  ipa="$out/GestaltX_$version+$build.ipa"
else
  ipa="$out/GestaltX_$version.ipa"
fi
rm -f "$ipa"
(cd "$stage" && zip -qry "$ipa" Payload)
echo "==> Wrote $ipa"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=$version"
    echo "build=$build"
    echo "ipa=$ipa"
  } >> "$GITHUB_OUTPUT"
fi
