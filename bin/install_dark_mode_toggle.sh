#!/bin/bash

# Builds an app bundle in ~/Applications, which is where Alfred and Spotlight look for launchables.
set -euo pipefail

APP="$HOME/Applications/Toggle Dark Mode.app"
BUNDLE_ID="com.tommaso.toggle-dark-mode"

mkdir -p "$HOME/Applications"
rm -rf "$APP"
osacompile -o "$APP" \
    -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode'

PLIST="$APP/Contents/Info.plist"
# Agent, not app: toggling the theme shouldn't bounce the Dock or steal focus.
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$PLIST"
# osacompile leaves out CFBundleIdentifier, and TCC can't hang an Automation grant on a bundle-less app.
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST"
codesign --force --sign - "$APP"

# A denied or interrupted prompt is remembered forever; clearing it fails harmlessly on a first install.
tccutil reset AppleEvents "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "Built $APP"
echo "Launching it once for the Automation prompt — click OK."
open -a "$APP"
