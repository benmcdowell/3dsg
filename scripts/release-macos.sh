#!/usr/bin/env bash
set -euo pipefail

PRODUCT="3dsg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
STAGING_DIR="$DIST_DIR/staging"

fail() {
  printf 'error: %s\n' "$*" >&2
  printf 'Run %s --help for usage.\n' "$0" >&2
  exit 2
}

usage() {
  cat <<'EOF'
Usage:
  scripts/release-macos.sh --help
  VERSION=0.1.1 CODESIGN_IDENTITY="Developer ID Application: ..." NOTARYTOOL_PROFILE=3dsg-notarytool scripts/release-macos.sh

Build, sign, notarize, package, and publish a macOS release for 3dsg.

This script creates a GitHub Release. It does not push commits or tags, so run it
from the clean commit you want to release after that commit has been pushed to
GitHub.

Required environment:
  VERSION               Release version, without the leading "v".
                        Must match ToolVersion.current.

  CODESIGN_IDENTITY     Developer ID Application identity used by codesign.
                        Example: Developer ID Application: Your Name (TEAMID)

  NOTARYTOOL_PROFILE    Stored notarytool credentials profile.
                        Create it with:
                        xcrun notarytool store-credentials 3dsg-notarytool

Optional environment:
  GH_REPO               GitHub repository in OWNER/REPO form. The script tries
                        to infer this from git first.

  RELEASE_NOTES         Literal release notes for gh release create.

  RELEASE_NOTES_FILE    Path to a Markdown release notes file. Takes precedence
                        over RELEASE_NOTES.

Prerequisites:
  - swift, codesign, ditto, gh, shasum, xcrun, and zipinfo must be on PATH.
  - gh must be authenticated: gh auth login
  - A Developer ID Application certificate must be installed locally.
  - Notary credentials must be stored in the named NOTARYTOOL_PROFILE.
  - The working tree must be clean.
  - The current commit must already exist on GitHub.
  - The GitHub release tag v$VERSION must not already exist.

Example:
  VERSION=0.1.1 \
  CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  NOTARYTOOL_PROFILE=3dsg-notarytool \
  GH_REPO=benmcdowell/3dsg \
  scripts/release-macos.sh

Outputs:
  dist/3dsg-$VERSION-macos-universal.zip
  dist/SHA256SUMS
  https://github.com/$GH_REPO/releases/tag/v$VERSION
EOF
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

verify_archive_contents() {
  local archive="$1"
  local listing

  listing="$(zipinfo -1 "$archive")" || fail "could not inspect archive contents"
  if [[ "$listing" != "$PRODUCT" ]]; then
    printf 'archive contents:\n%s\n' "$listing" >&2
    fail "release archive must contain only $PRODUCT at the archive root"
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

case "${1:-}" in
  -h|--help|help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    fail "unexpected argument: $1"
    ;;
esac

require_env VERSION
require_env CODESIGN_IDENTITY
require_env NOTARYTOOL_PROFILE

require_command swift
require_command codesign
require_command ditto
require_command gh
require_command shasum
require_command xcrun
require_command zipinfo

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

gh auth status >/dev/null 2>&1 || fail "gh is not authenticated; run gh auth login"

github_repo="${GH_REPO:-}"
if [[ -z "$github_repo" ]]; then
  github_repo="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [[ -z "$github_repo" ]]; then
  fail "could not determine GitHub repository; set GH_REPO=OWNER/REPO"
fi
gh repo view "$github_repo" >/dev/null 2>&1 || fail "gh cannot access repository $github_repo"

if [[ -n "$(git status --porcelain)" ]]; then
  fail "working tree is not clean; commit or stash changes before releasing"
fi

release_tag="v$VERSION"
release_title="$PRODUCT $VERSION"
target_commit="$(git rev-parse HEAD)"

gh api "repos/$github_repo/commits/$target_commit" >/dev/null 2>&1 ||
  fail "current commit $target_commit is not available on GitHub; push it before releasing"

if gh release view "$release_tag" --repo "$github_repo" >/dev/null 2>&1; then
  fail "GitHub release $release_tag already exists in $github_repo"
fi

release_notes_args=(--generate-notes)
if [[ -n "${RELEASE_NOTES_FILE:-}" ]]; then
  release_notes_args=(--notes-file "$RELEASE_NOTES_FILE")
elif [[ -n "${RELEASE_NOTES:-}" ]]; then
  release_notes_args=(--notes "$RELEASE_NOTES")
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
ditto -c -k --norsrc --noextattr "$STAGING_DIR" "$archive"
verify_archive_contents "$archive"

printf 'Submitting %s for notarization...\n' "$archive"
xcrun notarytool submit "$archive" \
  --keychain-profile "$NOTARYTOOL_PROFILE" \
  --wait

printf 'Writing checksums...\n'
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$archive")" > SHA256SUMS
)

printf 'Creating GitHub release %s in %s...\n' "$release_tag" "$github_repo"
gh release create "$release_tag" \
  "$archive" \
  "$DIST_DIR/SHA256SUMS" \
  --repo "$github_repo" \
  --target "$target_commit" \
  --title "$release_title" \
  "${release_notes_args[@]}"

rm -rf "$STAGING_DIR"

printf 'Release artifact ready: %s\n' "$archive"
printf 'Checksums: %s\n' "$DIST_DIR/SHA256SUMS"
printf 'GitHub release: https://github.com/%s/releases/tag/%s\n' "$github_repo" "$release_tag"
