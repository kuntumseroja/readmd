#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

ICON_SRC="Resources/AppIcon-1024.png"
ICON_ICNS="Resources/AppIcon.icns"

if [[ ! -f "$ICON_SRC" ]]; then
  echo "missing $ICON_SRC" >&2
  exit 1
fi

if [[ ! -f "$ICON_ICNS" || "$ICON_SRC" -nt "$ICON_ICNS" ]]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  sips -z 16 16 "$ICON_SRC" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SRC" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SRC" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SRC" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SRC" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SRC" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SRC" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$ICON_ICNS"
fi

swift build -c release --arch arm64 --arch x86_64 --product ReadMe
swift build -c release --arch arm64 --arch x86_64 --product read.me
APP="dist/read.me.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/ReadMe "$APP/Contents/MacOS/ReadMe"
cp Info.plist "$APP/Contents/Info.plist"
cp .build/release/read.me "$APP/Contents/MacOS/read.me"
cp "$ICON_ICNS" "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "Built $APP"
echo "CLI: $APP/Contents/MacOS/read.me"
echo "Open: open \"$APP\""
