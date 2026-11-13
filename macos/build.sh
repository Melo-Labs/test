#!/bin/bash
# Baut "Kilo für Kilo.app" auf einem Mac.  Aufruf:  ./macos/build.sh  [install|dmg]
# Voraussetzung: Xcode Command Line Tools (xcode-select --install)
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="Kilo für Kilo"
APP="build/$NAME.app"

if ! command -v swiftc >/dev/null; then
  echo "swiftc fehlt. Bitte zuerst ausführen: xcode-select --install" >&2
  exit 1
fi

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal-Binary für Apple Silicon und Intel
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos11.0" -o "build/kilo-$arch" macos/main.swift
done
lipo -create build/kilo-arm64 build/kilo-x86_64 -output "$APP/Contents/MacOS/KiloFuerKilo"
rm build/kilo-arm64 build/kilo-x86_64

cp macos/Info.plist "$APP/Contents/Info.plist"
cp index.html "$APP/Contents/Resources/index.html"

# App-Icon aus macos/icon.png erzeugen
ICONSET="build/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" macos/icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" macos/icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

codesign --force --sign - "$APP"
echo "Fertig: $APP"

if [ "${1:-}" = "dmg" ]; then
  STAGE="build/dmg"
  rm -rf "$STAGE" build/Kilo-fuer-Kilo.dmg
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  # hdiutil meldet auf CI-Rechnern gelegentlich "Resource busy" – bis zu dreimal versuchen
  for try in 1 2 3; do
    if hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO build/Kilo-fuer-Kilo.dmg; then break; fi
    [ "$try" = 3 ] && exit 1
    sleep 5
  done
  rm -rf "$STAGE"
  echo "Fertig: build/Kilo-fuer-Kilo.dmg"
fi

if [ "${1:-}" = "install" ]; then
  rm -rf "/Applications/$NAME.app"
  cp -R "$APP" "/Applications/$NAME.app"
  echo "Installiert in /Applications. Starte die App ..."
  open "/Applications/$NAME.app"
fi
