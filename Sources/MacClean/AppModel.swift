import SwiftUI
import AppKit
import MacCleanCore

enum AppSection:String,CaseIterable,Identifiable {
    case overview="Overview",cleanup="Cleanup",projects="Projects & worktrees",storage="Storage",tools="Tools",engine="Mole engine",history="Operation history",settings="Settings & exclusions"
    var id:String { rawValue }
    var icon:String { switch self { case .overview:return "square.grid.2x2";case .cleanup:return "sparkles";case .projects:return "folder";case .storage:return "internaldrive";case .tools:return "wrench.and.screwdriver";case .engine:return "gearshape.2";case .history:return "clock.arrow.circlepath";case .settings:return "slider.horizontal.3" } }
}
struct SavedState:Codable { var roots:[String];var exclusions:Set<String>;var operations:[OperationRecord] }
@MainActor final class AppModel:ObservableObject {
    @Published var section:AppSection = .overview
    @Published var engine=EngineInfo()
    @Published var latestVersion:String?
    @Published var updateMessage="Not checked"
    @Published var busy=false
    @Published var progress=""
    @Published var error:String?
    @Published var findings=[Finding]()
    @Published var selected=Set<String>()
    @Published var inspected:String?
    @Published var search=""
    @Published var toolFilter="All tools"
    @Published var notices=[String]()
    @Published var roots=[String]()
    @Published var exclusions=Set<String>()
    @Published var operations=[OperationRecord]()
    @Published var analysis:Analysis?
    @Published var snapshot:SystemSnapshot?
    @Published var moleReport=""
    @Published var scannedAt:Date?
    @Published var review=false
    @Published var engineReview=false
    @Published var acknowledgement=false
    let mole=MoleService()
    let inventory=InventoryService()
    private let stateURL:URL
    init() {
        let home=FileManager.default.homeDirectoryForCurrentUser
        stateURL=home.appendingPathComponent("Library/Application Support/MacClean/state.json")
        roots=[home.appendingPathComponent("development/projects").path,home.appendingPathComponent("Projects").path].filter{FileManager.default.fileExists(atPath:$0)}
        if FileManager.default.fileExists(atPath:stateURL.path) {
            do { let saved=try JSONDecoder().decode(SavedState.self,from:Data(contentsOf:stateURL));roots=saved.roots;exclusions=saved.exclusions;operations=saved.operations }
            catch { self.error="Saved settings could not be read: \(error.localizedDescription)" }
        }
    }
    var selectedFindings:[Finding] { findings.filter{selected.contains($0.id)} }
    var selectionBytes:Int64 { selectedFindings.compactMap(\.bytes).reduce(0,+) }
    var freeBytes:Int64? { (try? FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys:[.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage }
    var totalBytes:Int64? { guard let n=(try? FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys:[.volumeTotalCapacityKey]))?.volumeTotalCapacity else{return nil};return Int64(n) }
    func start(_ message:String,_ work:@escaping @MainActor () async throws -> Void) {
        guard !busy else { return };busy=true;progress=message;error=nil
        Task { defer { busy=false;progress="" };do { try await work() } catch { self.error=error.localizedDescription } }
    }
    func detect() { start("Detecting Mole…") { self.engine=await self.mole.detect();self.updateMessage="Not checked";self.latestVersion=nil } }
    func chooseEngine() {
        let panel=NSOpenPanel();panel.canChooseDirectories=false;panel.canChooseFiles=true;panel.message="Choose the Mole executable (mo). It will be run to verify its version."
        guard panel.runModal() == .OK,let url=panel.url else{return}
        start("Verifying selected Mole executable…") { self.engine=await self.mole.detect(customPath:url.path);self.updateMessage="Not checked" }
    }
    func scan() { start("Inspecting developer caches, containers and projects…") {
        let result=await self.inventory.scan(roots:self.roots,exclusions:self.exclusions,progress:{ message in await MainActor.run { self.progress=message } })
        self.findings=result.findings;self.notices=result.notices;self.selected.removeAll();self.inspected=result.findings.first?.id;self.scannedAt=Date()
    } }
    func checkUpdates() { start("Checking Homebrew’s published Mole release…") {
        do {
            let latest=try await self.mole.latestVersion();self.latestVersion=latest
            if let installed=self.engine.version,let newer=Versions.isNewer(latest,than:installed) { self.updateMessage=newer ? "Update available: \(latest)" : "Installed version is current or newer than Homebrew’s release." }
            else { self.updateMessage="Available from Homebrew: \(latest)" }
        } catch { self.latestVersion=nil;self.updateMessage="Latest version unknown";throw error }
    } }
    func executeEngineChange() {
        engineReview=false
        start(engine.path == nil ? "Installing Mole with Homebrew…" : "Upgrading Mole with Homebrew…") {
            let title=self.engine.path == nil ? "Install Mole" : "Upgrade Mole"
            do {
                let log=try await self.mole.installOrUpgrade(self.engine)
                self.engine=await self.mole.detect()
                guard self.engine.ready else { throw CommandError.failed("The package manager finished, but Mole verification failed. Detect again before cleanup.") }
                self.operations.insert(OperationRecord(title:title,outcome:"Completed",detail:String(log.suffix(6000))),at:0);self.persist();self.updateMessage="Detecting available updates is a separate check."
            } catch { self.operations.insert(OperationRecord(title:title,outcome:"Failed",detail:error.localizedDescription),at:0);self.persist();throw error }
        }
    }
    func executeCleanup() {
        let actions=selectedFindings
        guard acknowledgement,!actions.isEmpty else{return}
        review=false;acknowledgement=false
        start("Moving selected caches to Trash…") {
            let service=CleanupService()
            for finding in actions {
                let record=await service.moveToTrash(finding)
                self.operations.insert(record,at:0)
                if record.outcome=="Moved to Trash" { self.findings.removeAll{$0.id==finding.id} }
                self.selected.remove(finding.id);self.persist()
            }
            self.section = .history
        }
    }
    func refreshStatus() { start("Collecting a system snapshot from Mole…") { self.snapshot=try await self.mole.status(self.engine) } }
    func previewMole() { start("Running Mole’s read-only cleanup preview…") { self.moleReport=try await self.mole.cleanupPreview(self.engine) } }
    func chooseAnalysisFolder() {
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.message="Choose a directory for Mole to inspect."
        guard panel.runModal() == .OK,let url=panel.url else{return};analyze(url.path)
    }
    func analyze(_ path:String) { start("Analyzing \(path)…") { self.analysis=try await self.mole.analyze(self.engine,path:path) } }
    func addRoot() {
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.allowsMultipleSelection=true
        guard panel.runModal() == .OK else{return}
        roots=Array(Set(roots+panel.urls.map(\.path))).sorted();persist()
    }
    func exclude(_ finding:Finding) { exclusions.insert(finding.path);selected.remove(finding.id);findings.removeAll{$0.id==finding.id};persist() }
    func persist() {
        do {
            try FileManager.default.createDirectory(at:stateURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONEncoder().encode(SavedState(roots:roots,exclusions:exclusions,operations:Array(operations.prefix(500)))).write(to:stateURL,options:.atomic)
        } catch { self.error="Could not save settings or history: \(error.localizedDescription)" }
    }
    func reveal(_ path:String) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:path)]) }
}
