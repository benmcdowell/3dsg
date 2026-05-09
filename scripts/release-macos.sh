#!/usr/bin/env bash
set -euo pipefail

PRODUCT="3dsg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
STAGING_DIR="$DIST_DIR/staging"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    fail "$name is required"
  fi
}

require_command() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    fail "$name is required but was not found on PATH"
  fi
}

release_binary_path() {
  local candidates=(
    "$REPO_ROOT/.build/apple/Products/Release/$PRODUCT"
    "$REPO_ROOT/.build/release/$PRODUCT"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

require_env VERSION
require_env CODESIGN_IDENTITY
require_env NOTARYTOOL_PROFILE

require_command swift
require_command codesign
require_command ditto
require_command shasum
require_command xcrun

cd "$REPO_ROOT"

declared_version="$(
  sed -nE 's/^[[:space:]]*public static let current = "([^"]+)".*$/\1/p' \
    Sources/ThreeDSGCore/ToolVersion.swift
)"
if [[ -z "$declared_version" ]]; then
  fail "could not read ToolVersion.current"
fi
if [[ "$declared_version" != "$VERSION" ]]; then
  fail "VERSION ($VERSION) does not match ToolVersion.current ($declared_version)"
fi

printf 'Building %s %s for macOS release...\n' "$PRODUCT" "$VERSION"
swift build -c release --product "$PRODUCT" --arch arm64 --arch x86_64

binary_path="$(release_binary_path)" || fail "release binary not found after build"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp "$binary_path" "$STAGING_DIR/$PRODUCT"
chmod 0755 "$STAGING_DIR/$PRODUCT"

if command -v lipo >/dev/null 2>&1; then
  lipo -info "$STAGING_DIR/$PRODUCT"
fi

printf 'Signing %s...\n' "$STAGING_DIR/$PRODUCT"
codesign \
  --force \
  --options runtime \
  --timestamp \
  --sign "$CODESIGN_IDENTITY" \
  "$STAGING_DIR/$PRODUCT"

codesign --verify --strict --verbose=2 "$STAGING_DIR/$PRODUCT"

mkdir -p "$DIST_DIR"
archive="$DIST_DIR/$PRODUCT-$VERSION-macos-universal.zip"
rm -f "$archive"

printf 'Packaging %s...\n' "$archive"
(
  cd "$STAGING_DIR"
  ditto -c -k --keepParent "$PRODUCT" "$archive"
)

printf 'Submitting %s for notarization...\n' "$archive"
xcrun notarytool submit "$archive" \
  --keychain-profile "$NOTARYTOOL_PROFILE" \
  --wait

printf 'Writing checksums...\n'
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$archive")" > SHA256SUMS
)

rm -rf "$STAGING_DIR"

printf 'Release artifact ready: %s\n' "$archive"
printf 'Checksums: %s\n' "$DIST_DIR/SHA256SUMS"
