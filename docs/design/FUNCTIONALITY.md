# MacClean interaction and functionality proposal

Status: design prototype for review, not production implementation. All inventory, measurements, and operation outcomes in the browser are illustrative. The backend remains disconnected.

## Navigation

- Overview: storage allocation, grouped findings, manual scan entry, inspection totals rather than promises of savings.
- Cleanup: developer-tool caches and application/download findings. Search by tool, name or path; filter by tool; inspect before selecting.
- Projects & worktrees: aggregate findings by project; distinguish generated output, environments, existing checkouts and stale registrations.
- Storage: read-only folder exploration plus tool-managed container inventory.
- Tools: app removal, system status and individual maintenance tasks. No blanket optimization action.
- History: per-item completed, failed and skipped results.
- Settings: scan roots, exclusions, permission status, manual-approval policy.

## Shared workflow

1. Discover installed tools, configured cache locations and selected project roots. Show unsupported tools, unavailable machines and restricted paths explicitly.
2. Build findings with stable identity, owner, paths, byte count, sizing method, cause, risk, removal method, recreation cost and evidence timestamp.
3. Allow inspection without selection. Start with nothing selected. Rebuildable-only selection never includes downloads, worktrees, persistent data or unknown ownership.
4. Maintain selection across screens and filters. Exclusion removes an item from selection and remains independently reversible.
5. Review every selected action, recovery implications, and potential disruption. Distinguish file bytes, exclusive reclaimable bytes, deferred Trash savings and unknown estimates.
6. Revalidate identity, paths, ownership and active usage immediately before each operation. Changes or uncertainty cause a skip, not a broader deletion.
7. Execute through the owning tool where possible. Report each outcome and actual host free-space change separately. Never describe an error as successful removal.

## Developer coverage

Use a provider registry, not a fixed language-specific interface. Each provider declares discovery, inspection, supported operations, exclusions, permissions, cancellation semantics and verification.

Initial coverage candidates: Go; Node.js/npm/pnpm/yarn; Python/pip/uv/virtual environments; Rust/Cargo; Java/Kotlin/Gradle/Maven; Swift/Xcode/Swift Package Manager; .NET/NuGet; Ruby/Bundler; PHP/Composer; Homebrew; Docker; Podman; Colima; OrbStack; Rancher Desktop; Lima; containerd/nerdctl contexts where supported; Git; editors; simulators and emulators. Exact installed Mole coverage must be verified provider by provider before implementation.

Project artifacts require project-context validation: a directory named build, bin, vendor or target is not inherently disposable. Tracked files, nested repositories, editable dependencies and custom cache paths require special handling. Unknown tools produce read-only inventory rather than generic deletion rules.

Container discovery identifies the actual engine, socket, context/profile and namespace behind each desktop application or virtual-machine manager. Multiple frontends for the same endpoint must not duplicate findings or savings. Local Kubernetes references must be respected. Unsupported or unavailable engines remain inspect-only.

Container inventory separates images, stopped containers, build caches, volumes and virtual-machine disks. Shared image layers are counted once when estimates permit. Volumes remain protected by default. Host disk reclamation is distinct from free space inside a virtual machine. Starting a stopped machine or reclaiming its disk requires an explicit operation.

Worktree inspection checks Git registration, actual location, mounted-volume availability, lock status, dirty/untracked/ignored data, unique commits and application/agent ownership. Use the owning application's archive operation for its managed worktrees where available. A clean Git status or age alone does not authorize removal. Pruning a missing registration is bookkeeping and normally yields negligible disk savings.

## Boundaries and states

Production design must cover no supported tools, empty findings, cancelled/partial scans, permission denial, disconnected container engine, excluded roots, stale results, source changes after review, operation cancellation and partial failure. Retry operates only on remaining findings after revalidation.

Caches may be permanently removed using owner-tool commands; this is disclosed before execution. Trash provides recovery only until emptied and does not count as immediate reclamation. No universal Undo promise. Credentials, personal documents, source changes and persistent databases stay protected.

## Clickable prototype scope

Implemented: navigation; sample scan progress; search/filter; item inspection; persistent cross-screen selection within the session; protected findings; exclusions/restoration; acknowledgement before simulated cleanup; completion and partial-failure history; responsive layouts.

Concept-only: app-removal execution, maintenance execution, live monitoring, arbitrary disk navigation, editable scan roots, operating-system permissions and real provider integration. Reload or Reset preview clears all demonstration state.

## Implementation decisions still open

Native framework and packaging, backend protocol, whether Mole requires a structured wrapper or a pinned fork, provider test fixtures, permission architecture, operation cancellation and restore manifests. Do not claim arbitrary per-item engine selection is supported until the installed commands have been validated.

## Mole lifecycle management
Detect executable paths, version, installation source and multiple copies. Offer installation when missing, using existing Homebrew or a separately reviewed supported route. Never install a package manager silently. Check update availability separately from compatibility, with unknown/offline states. Update through the owning installation method after explicit review and when no operation is running. Re-detect and verify capabilities after changes; block Mole operations if absent or unverifiable, retain independent provider inventory. Preserve exclusions and diagnostic logs; offer retry/manual instructions after failures. Preview scenarios simulate these states; they do not install or query releases.
