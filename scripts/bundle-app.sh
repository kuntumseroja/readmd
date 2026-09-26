#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product ReadMe
swift build -c release --product read.me
APP="dist/read.me.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ReadMe "$APP/Contents/MacOS/ReadMe"
cp Info.plist "$APP/Contents/Info.plist"
cp .build/release/read.me "$APP/Contents/MacOS/read.me"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "Built $APP"
echo "CLI: $APP/Contents/MacOS/read.me"
echo "Open: open \"$APP\""
