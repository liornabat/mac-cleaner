#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
app_dir="$PWD/dist/MacClean.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp .build/release/MacClean "$app_dir/Contents/MacOS/MacClean"
cp Sources/MacClean/Resources/MacCleanIcon.png "$app_dir/Contents/Resources/MacCleanIcon.png"
./scripts/build-icons.sh
cp dist/MacClean.icns "$app_dir/Contents/Resources/MacClean.icns"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MacClean</string>
<key>CFBundleDisplayName</key><string>MacClean</string>
<key>CFBundleIdentifier</key><string>com.liornabat.macclean</string>
<key>CFBundleExecutable</key><string>MacClean</string>
<key>CFBundleIconFile</key><string>MacClean.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
printf 'Built %s\n' "$app_dir"
