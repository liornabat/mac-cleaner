# Versioning and test releases

`Sources/MacClean/Resources/AppVersion.json` is the only version source. Its three-number release version becomes the repository tag `v<version>`, package filename, bundle version and visible app version. Its positive build number identifies the build in the app and bundle. The sidebar and native About window show both numbers. Swift Package Manager development runs read the same resource; packaged apps use bundle metadata.

## Create the next release

```sh
./scripts/version.py bump patch
# Use minor for new functionality, or major for a breaking change.
# Update CHANGELOG.md and commit the version plus release changes.
git add Sources/MacClean/Resources/AppVersion.json CHANGELOG.md
git commit -m "Prepare the next MacClean release"
git push
./scripts/tag-release.sh
```

The tag script requires a clean checkout and refuses existing local or remote tags. It runs version tests and application tests, creates an annotated tag at the current commit and pushes it to origin. Use the intended reviewed commit; this script never merges branches. Tags are immutable release identities. To fix a published build, increment the version and release again.

The tag-triggered GitHub Actions workflow verifies tag/version agreement, runs tests, builds Apple Silicon and Intel separately, combines them into a universal executable, and creates ZIP and disk-image downloads. It verifies the signature, both architectures and disk image, then adds SHA-256 checksums. Packages are retained as workflow artifacts if publication fails. A draft release receives the assets before publication as a prerelease. Existing releases are not overwritten.

All current releases are explicitly test prereleases. They are locally signed with an ad-hoc signature and are not Apple-notarized. No Apple account or signing secret is needed. Downloaded builds can require explicit approval in macOS Privacy & Security. Do not disable system protections. Mole remains external; MacClean detects it and offers installation through existing Homebrew, or links to manual setup.

## Build without publishing

```sh
./scripts/test-version.py
./scripts/test.sh
./scripts/build-app.sh        # This Mac's architecture
./scripts/package-app.sh      # Universal app, ZIP, disk image, checksums
```

Requires Swift 6, Command Line Tools and the macOS `lipo`, `ditto` and `hdiutil` utilities. No full Xcode installation is required for the separate architecture builds. Outputs stay in ignored `dist/`. The application supports macOS 14 or later; actual Intel hardware still needs tester qualification.

Version 0.1.0 / build 1 is the first repository prerelease. Future Apple signing/notarization can extend this workflow without changing the version source or tag convention.
