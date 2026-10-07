# Native layout and functionality review

Reviewed on 7 October 2026 on the user's Mac, macOS 27, with installed Mole 1.56.0. The release application was built using Swift 6.2.3. This review covers implemented behavior, not complete parity with the proposed feature set.

## Layout findings addressed

The reported Cleanup failure was reproduced: the empty split layout escaped the content region and displaced the native window shell. The workspace and findings now use bounded SwiftUI stacks. The sidebar, heading, search, filters, empty state and inspector remain within the window. A native quarter-window arrangement exercised approximately 961 × 703 points; default size is 1220 × 820 and the declared minimum is 960 × 650. Exact minimum-height resizing was not separately exercised.

Search and tool filters belong to each findings screen. No-match results clear unrelated inspector actions and offer Clear filters. Category-empty and before-scan states explain the next action. Long diagnostics and notices scroll within bounded regions. Paths wrap or truncate where appropriate. Sidebar hiding and restoration work. Settings offer persisted app-only System, Light and Dark appearances. Opaque secondary, success and warning colors replace faint small text in light appearance.

The Overview container action selects the container view. Missing Mole has a direct setup action. Folder analysis shows count, measured total and explicit empty results. Engine controls wrap at compact widths. Escape dismisses cleanup and package reviews. History includes time as well as date. Container summaries present recognized provider fields and retain unknown formats in the raw report.

## Functional changes addressed

Custom engine selection survives relaunch and Detect again. Automatic detection can be restored. Incompatible Homebrew engines retain installation provenance so the repair action remains available. An upgrade of a version-specific Homebrew selection follows the stable package executable afterward rather than continuing to verify the old version. Failed update checks leave the latest version unknown.

Container exclusions apply before commands run. Repeated worktree registrations produce unique findings. Versioned and framework process names protect active caches. Corrupt saved state is reported and backed up before replacement. Preview checks that Mole advertises --dry-run and passes both the flag and dry-run environment setting. No arbitrary selection is delegated to broad Mole cleanup.

## Automated verification

All 38 tests in four suites pass. Provider checks cover missing and incompatible engines, package success/failure/timeouts, literal path arguments, preview refusal and dry-run execution, unavailable connections and directories, exclusions and restoration, repeated worktrees and active versioned Python. Cleanup tests cover approved exact paths, symbolic links, changed directory identity, unknown sizes, protected findings, partial outcomes and recovery paths. One disposable temporary cache fixture is moved through native Finder Trash and restored.

Application checks cover persisted custom engine and appearance, stable Homebrew executable after upgrade, corrupt-state backup, competing-operation refusal, Overview navigation, system/analysis/preview state, package and cleanup history, artwork resource loading and container formats. Release packaging, bundle property list and local signature are verified. The bash test script handles empty arrays under the macOS default shell.

## Live native verification

The native app detects the installed engine. A real read-only scan produces cache, project and container findings with partial-coverage notices. Search, Clear filters, project tool filters, cache selection, inspector details and cleanup review were exercised. The Trash action remains disabled before acknowledgement; review was cancelled without removing user data. Container summaries and protected project rows remain unselectable. The real system snapshot refresh produces current measurements. History empty state and sidebar toggling work.

No user cache cleanup, actual Mole installation or upgrade was performed. Package mutations are verified with controlled command fixtures. The native executable chooser opens and cancels correctly. The live update check reports Homebrew version 1.58.0. Upgrade review shows the package command and Escape cancels it. Folder selection, real Mole analysis, directory drill-down, parent navigation and Reveal in Finder work against the application source folder. The read-only cleanup preview produces real output and labels its partial report when the 180-second deadline expires. Final light and system-dark captures preserve the compact layout; System appearance was restored after verification.

## Remaining product boundaries

Container images, containers, volumes, worktrees and project artifacts are inspection-only. Docker and Podman current connections are supported; broader contexts and other runtimes still need adapters. Cache discovery uses an initial curated catalog. Repository discovery and subprocesses have finite budgets and may report partial results. Scans can race with tools restarting, so each removal revalidates the owner and directory identity. Cancellation, maintenance execution, app uninstallation and continuous monitoring remain unimplemented. macOS 14–26 were not visually exercised; the package targets macOS 14 or later.
