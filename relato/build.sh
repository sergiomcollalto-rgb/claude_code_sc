#!/bin/bash
# Compila o Relato e monta o Relato.app nesta pasta.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Relato"

APP="Relato.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Relato"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo
echo "Pronto: $(pwd)/$APP"
echo "Abra com:  open $APP"
