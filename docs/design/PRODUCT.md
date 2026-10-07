# Product
<!-- impeccable:product-schema 1 -->
## Platform
web
Browser prototype for a future native macOS utility. No production stack decision yet.
## Stack
Self-contained HTML, CSS and JavaScript for the authorized clickable prototype.
## Users
One experienced developer, for personal use on their Mac.
## Product Purpose
Understand disk use and deliberately remove unnecessary files across applications, languages, developer tools, containers and projects.
## Operating Context
Installed Mole 1.56.0 supplies the core engine in the future app. Extend missing container coverage across Docker, Podman, Colima, OrbStack, Rancher Desktop, Lima and underlying engines/contexts, plus Git worktrees. The prototype never executes system commands.
## Capabilities and Constraints
Overview, cleanup, projects/worktrees, disk and container storage, app removal, monitoring, maintenance, exclusions and operation history. Manual scan and review before cleanup. Clearly distinguish rebuildable caches, downloadable dependencies and user data. Existing worktrees require changes/commit/ownership checks. Unknown state blocks removal. Volumes protected by default.
## Evidence on Hand
Mole version and installed scripts inspected in this chat. Every size, item and outcome in the preview is illustrative, not a scan of this Mac.
## Product Principles
- Broad discovery, explicit tool-specific removal rules.
- Never infer disposability from age alone.
- Review consequences and reversibility before action.
- Report skipped, failed and completed actions separately.
## Open Decisions
Final native implementation stack, packaging and detailed engine integration remain undecided. MacClean is a working title from the workspace.

## Mole lifecycle management
Detect executable paths, version, installation source and multiple copies. Offer installation when missing, using existing Homebrew or a separately reviewed supported route. Never install a package manager silently. Check update availability separately from compatibility, with unknown/offline states. Update through the owning installation method after explicit review and when no operation is running. Re-detect and verify capabilities after changes; block Mole operations if absent or unverifiable, retain independent provider inventory. Preserve exclusions and diagnostic logs; offer retry/manual instructions after failures. Preview scenarios simulate these states; they do not install or query releases.
