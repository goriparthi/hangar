#!/bin/bash
# Shared settings and helpers for every script in this repo. Sourced, not executed.
# Single source of truth for names and paths so a rename touches one file.

set -euo pipefail

APP_NAME="Hangar"
DISPLAY_NAME="Hangar"

# Repo root, resolved from this file so scripts work from any cwd
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

APP_DIR="$REPO_ROOT/app"
DIST_DIR="$REPO_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
INFO_PLIST="$APP_DIR/Resources/Info.plist"
ENTITLEMENTS="$APP_DIR/Resources/$APP_NAME.entitlements"
CATALOG="$APP_DIR/Resources/${APP_NAME}Assets.xcassets"
ICON_SRC="$APP_DIR/Resources/app-icon"
DEPLOY_TARGET="15.0"

# The profile name created with `xcrun notarytool store-credentials`. Not a secret;
# the credentials themselves stay in the login Keychain.
NOTARY_PROFILE="${NOTARY_PROFILE:-hangar-notary}"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
    "$INFO_PLIST" 2>/dev/null || echo "0.0.0")"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# xcode-select usually points at the Command Line Tools, which is all the Swift
# build needs. actool lives only inside Xcode.app, so resolve it directly.
find_actool() {
    if [[ -x /Applications/Xcode.app/Contents/Developer/usr/bin/actool ]]; then
        echo /Applications/Xcode.app/Contents/Developer/usr/bin/actool
    elif xcrun --find actool >/dev/null 2>&1; then
        xcrun --find actool
    fi
}

# Prefer a Developer ID cert (required for notarized distribution). Falls back to
# ad-hoc, which works locally but leaves downloads quarantined by Gatekeeper.
find_signing_identity() {
    if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
        echo "$CODESIGN_IDENTITY"
        return
    fi
    security find-identity -v -p codesigning 2>/dev/null \
        | grep "Developer ID Application" \
        | head -1 \
        | sed -E 's/.*"(.*)".*/\1/' \
        || true
}
