#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh --universal
app_version="$(./scripts/version.py version)"
package_name="MacClean-${app_version}-macos-universal"
package_dir="$PWD/dist/$package_name"
rm -rf "$package_dir"
mkdir -p "$package_dir"
cp -R dist/MacClean.app "$package_dir/MacClean.app"
ln -s /Applications "$package_dir/Applications"
cat > "$package_dir/READ ME.txt" <<'NOTES'
MacClean test build — macOS 14 or later, Apple Silicon and Intel.

Drag MacClean into Applications. This build is locally signed, not Apple-notarized.
macOS may require explicit approval in Privacy & Security before it opens.
Never disable Gatekeeper or other system protections to install it.

Mole is a separate dependency. Open the Mole engine page for detection and setup.
Install/upgrade uses existing Homebrew; MacClean does not install Homebrew itself.

Known developer caches can be moved to Finder Trash after review.
Containers, worktrees and project artifacts are inspection-only.
Trash retains removed data until emptied and does not immediately recover space.

Report issues: https://github.com/liornabat/mac-cleaner/issues
NOTES
ditto -c -k --sequesterRsrc --keepParent dist/MacClean.app "dist/$package_name.zip"
hdiutil create -volname "MacClean $app_version" -srcfolder "$package_dir" -ov -format UDZO "dist/$package_name.dmg"
hdiutil verify "dist/$package_name.dmg"
codesign --verify --deep --strict dist/MacClean.app
lipo dist/MacClean.app/Contents/MacOS/MacClean -verify_arch arm64 x86_64
(cd dist && shasum -a 256 "$package_name.zip" "$package_name.dmg" > "$package_name.sha256")
printf 'Packaged %s\n' "$package_name"
