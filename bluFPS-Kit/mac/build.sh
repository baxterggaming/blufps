#!/bin/bash
# Builds bluFPS.app from the Swift source with Apple's own (free) command line tools.
# Usage: bash build.sh [output.app] [--quiet]
cd "$(dirname "$0")" || exit 1
OUT="${1:-bluFPS.app}"
QUIET="$2"
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "bluFPS needs Apple's free command line tools to build."
  echo "A window will now ask you to install them. When it finishes, run this again."
  xcode-select --install 2>/dev/null
  exit 1
fi
case "$OUT" in /*) ;; *) OUT="$(pwd)/$OUT" ;; esac
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
ARCH="$(uname -m)"
echo "Building bluFPS (about a minute)..."
if ! swiftc -O -target "${ARCH}-apple-macos12.0" Sources/main.swift -o "$OUT/Contents/MacOS/bluFPS"; then
  echo "Build failed - see the messages above."
  exit 1
fi
cp Info.plist "$OUT/Contents/Info.plist"
cp bluFPS.icns bluFPS.png update-source.txt "$OUT/Contents/Resources/" 2>/dev/null
codesign --force --deep --sign - "$OUT" >/dev/null 2>&1
echo "Done: $OUT"
if [ "$QUIET" != "--quiet" ]; then open -R "$OUT"; fi
