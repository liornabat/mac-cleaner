# First native implementation

## Acceptance

Build and package on the user's Mac. Launch a native window. Detect the installed Mole version and installation source. Collect real storage and system data through Mole. Discover known developer caches and inspect container/worktree storage. Persist exclusions and history. A reviewed selected cache may be moved to Trash only after policy revalidation; protected, unknown, changed or symlinked paths cannot be removed.

## Architecture

The executable target owns the SwiftUI views and a main-actor model. The core target contains a bounded direct subprocess runner, typed Mole reads, developer inventory, a narrow cache allowlist and a Trash executor. No shell interpretation is used for path arguments. Network update metadata comes from Homebrew's published Mole formula; installations use the existing `brew` executable.

A shared busy state prevents concurrent inventory, package changes and cleanup. Update availability is not compatibility proof. Package completion is followed by engine detection. Settings and operations use atomic local JSON persistence. Each cache operation produces its own result so partial failures retain remaining files.

## Follow-up implementation

1. Structured selectable Mole provider integration, without passing arbitrary selections to broad cleanup.
2. Context-aware Docker/Podman inventory, per-image/container references and shared-layer accounting; adapters for Colima, OrbStack, Rancher Desktop, Lima and containerd.
3. Git unique-commit, ignored-file, lock and agent-ownership qualification; owner-managed archival where available.
4. Broader package-cache discovery and owner-command cleanup where Trash cannot preserve tool semantics.
5. App management, scoped maintenance, cancellation, continuous monitoring and distribution signing.

The native application is the implementation source. The HTML mockup remains a design reference.

## Native appearance

The app follows the Mac's light or dark appearance. Secondary actions use an adaptive blue tint, while prominent actions use white text on dark blue. Unknown inventory sizes remain explicit; displayed totals are measured inventory, not promised recovered space. Removal review states that Trash retains files until emptied.
