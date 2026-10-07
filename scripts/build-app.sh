#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/version.py validate
app_version="$(./scripts/version.py version)"
app_build="$(./scripts/version.py build)"
case "${1:-}" in
  "") swift build -c release; binary_path="$(swift build -c release --show-bin-path)/MacClean" ;;
  --universal)
    swift build -c release --arch arm64
    arm_binary="$(swift build -c release --arch arm64 --show-bin-path)/MacClean"
    swift build -c release --arch x86_64
    intel_binary="$(swift build -c release --arch x86_64 --show-bin-path)/MacClean"
    mkdir -p dist
    binary_path="$PWD/dist/MacClean-universal"
    lipo -create "$arm_binary" "$intel_binary" -output "$binary_path"
    ;;
  *) printf 'Usage: %s [--universal]\n' "$0" >&2;exit 1 ;;
esac
app_dir="$PWD/dist/MacClean.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_path" "$app_dir/Contents/MacOS/MacClean"
cp Sources/MacClean/Resources/AppVersion.json "$app_dir/Contents/Resources/AppVersion.json"
cp Sources/MacClean/Resources/MacCleanIcon.png "$app_dir/Contents/Resources/MacCleanIcon.png"
./scripts/build-icons.sh
cp dist/MacClean.icns "$app_dir/Contents/Resources/MacClean.icns"
cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MacClean</string>
<key>CFBundleDisplayName</key><string>MacClean</string>
<key>CFBundleIdentifier</key><string>com.liornabat.macclean</string>
<key>CFBundleExecutable</key><string>MacClean</string>
<key>CFBundleIconFile</key><string>MacClean.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$app_version</string>
<key>CFBundleVersion</key><string>$app_build</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - "$app_dir"
printf 'Built %s\n' "$app_dir"
