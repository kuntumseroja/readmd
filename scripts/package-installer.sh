#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/bundle-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
APP="dist/read.me.app"
PKG="dist/read.me-${VERSION}.pkg"
DMG="dist/read.me-${VERSION}.dmg"
ZIP="dist/read.me-${VERSION}.zip"

chmod +x scripts/pkg-scripts/postinstall
pkgbuild \
  --identifier me.read.app \
  --version "$VERSION" \
  --install-location /Applications \
  --component "$APP" \
  --scripts scripts/pkg-scripts \
  "$PKG"

STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/read.me.app"
ln -s /Applications "$STAGE/Applications"
cp README.md "$STAGE/README.md"
cat > "$STAGE/How to open.txt" <<'EOF'
read.me is a read-only folder viewer for Mac.

Install
1. Drag read.me into Applications.
2. If macOS says it cannot be opened, right-click the app, choose Open, then Open again.

After that, launch it from Applications or run:
  read.me .
from Terminal if you used the installer package.

See README.md on this disk for full details.
EOF
rm -f "$DMG"
diskutil image create from --format ULFO --volumeName "read.me" "$STAGE" "$DMG"
rm -rf "$STAGE"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "Share any of these:"
echo "  $PKG"
echo "  $DMG"
echo "  $ZIP"
