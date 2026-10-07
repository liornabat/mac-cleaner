# MacClean

A native macOS utility for personal storage inspection and reviewed developer-cache cleanup. Built with SwiftUI for macOS 14 or later, using an externally installed Mole engine. No Mole source or binary is bundled.

## Build and run

Requires Swift 6 and Apple's Command Line Tools. No Xcode project or external Swift package dependency is required.

```sh
./scripts/test.sh
./scripts/build-app.sh
open dist/MacClean.app
```

The packaged application is locally ad-hoc signed. It is not notarized for distribution. You can also open `Package.swift` in Xcode or run `swift run MacClean` for development.

## Versions and downloads

The app shows its release version and build number in the sidebar and About window. Both come from `Sources/MacClean/Resources/AppVersion.json`, which also drives the app bundle, `v0.1.0` repository tag and release package names.

[Download test releases](https://github.com/liornabat/mac-cleaner/releases) or build locally. These builds are locally signed and not Apple-notarized; macOS can require explicit approval to open downloads. Mole remains separately installed. Read [the release instructions](docs/RELEASING.md) and [changelog](CHANGELOG.md).

```sh
./scripts/version.py bump patch  # Increment version and build, then commit
./scripts/tag-release.sh         # Test, create/push tag; GitHub Actions publishes packages
./scripts/package-app.sh         # Build universal packages locally without publishing
```

## Implemented

- Bounded native sidebar, findings list, details panel and review workflow, including meaningful empty and filtered states.
- Matching app, Dock and launcher artwork, with optional System, Light and Dark appearance.
- Mole executable detection, version verification and Homebrew installation-source detection.
- Explicit update checks against Homebrew's published formula. Reviewed install/upgrade through existing Homebrew; custom installations retain their own update route.
- Developer cache inventory for Go, npm, Python/pip/uv, Cargo, Gradle, Xcode, NuGet, Composer and Homebrew where standard locations exist.
- Reviewed cache removal to Finder's Trash, with approved-path checks, symlink refusal, current owner-process checks and scan-identity revalidation. No automatic emptying of Trash.
- Read-only inspection of the current Docker and Podman connections, discovered container tools, repository worktrees and common project artifacts.
- Mole folder analysis using JSON, a system snapshot, and a non-destructive cleanup preview.
- Persistent custom Mole executable, scan roots, exclusions and per-operation history under `~/Library/Application Support/MacClean`.

## Current boundaries

This is the first implementation, not full feature parity with the design.

- Mole 1.56 does not support arbitrary selected-file cleanup. MacClean invokes its `clean --dry-run` report only; selected developer caches use their own bounded Trash operation rather than broad `mo clean`.
- Container, worktree and project-artifact deletion is inspection-only. Discovery does not start virtual machines. Only each CLI's current connection is scanned; additional contexts/namespaces, full OrbStack/Rancher Desktop/Lima coverage and shared-endpoint deduplication still need implementation.
- Cache roots are a curated initial catalog. Custom language-tool locations are not yet discovered, and cache files can be recreated while a tool resumes running. Trash gives recovery until emptied; it does not immediately reclaim space.
- Scans have a 60-second budget and report partial results on expiry. Git discovery searches three directory levels and at most 60 repositories per root. It reports clean/dirty status but does not qualify ignored data, unique commits or coding-agent ownership for removal.
- System status is a manually refreshed snapshot. App uninstallation, maintenance execution, automatic schedules and continuous monitoring are not yet implemented.
- Long subprocesses have timeouts; there is no user-facing cancellation yet. Package-manager actions cannot request an administrator password and will report failure when interaction is needed.
- Permission-restricted scans may be partial. Review scan notices and errors. Full Disk Access is optional and granted in macOS Settings.

No actual user cleanup or package installation is run during development verification. All 39 automated checks cover temporary fixtures, cleanup rejection paths, provider failures, state persistence and subprocess execution. A disposable fixture exercises actual Finder Trash and restoration. Install/upgrade tests use controlled commands. See [review and verification](docs/REVIEW.md).

## Repository layout

- `Sources/MacClean`: native application and views.
- `Sources/MacCleanCore`: command execution, Mole integration, inventory, and cleanup policy.
- `Tests/MacCleanCoreTests`: deletion protections and provider boundaries.
- `Tests/MacCleanTests`: application workflows, persistence and resource loading.
- `docs/BRAND.md`: artwork source and reproducible icon packaging.
- `docs/design`: reviewed browser prototype and functionality proposal; demonstration data is not current machine inventory.
- `scripts/build-app.sh`: release executable and local `.app` packaging.
- `scripts/version.py`: single-source version validation and increments.
- `scripts/package-app.sh`: universal application, disk image, ZIP and checksums.
- `.github/workflows/release.yml`: validated tags and downloadable prereleases.

The repository code is Apache-2.0 licensed. Mole remains a separately installed external tool governed by its own license.
