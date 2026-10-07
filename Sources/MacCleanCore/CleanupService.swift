import Foundation

public final class CleanupService: Sendable {
    private let processes:@Sendable () async -> Set<String>
    private let trash:@Sendable (URL) throws -> URL?
    public init(processes:@escaping @Sendable () async -> Set<String> = { await InventoryService().runningProcesses() },trash:@escaping @Sendable (URL) throws -> URL? = { url in var destination:NSURL?;try FileManager.default.trashItem(at:url,resultingItemURL:&destination);return destination as URL? }) { self.processes=processes;self.trash=trash }
    /// Called only after native review. This never delegates a selection to `mo clean`.
    public func moveToTrash(_ finding:Finding, home:URL=FileManager.default.homeDirectoryForCurrentUser) async -> OperationRecord {
        do {
            guard finding.canClean else { throw CommandError.failed("This finding is inspection-only.") }
            if let reason=CleanupPolicy.validate(path:finding.path,home:home) { throw CommandError.failed(reason) }
            guard let spec=CacheCatalog.spec(for:finding.path,home:home) else { throw CommandError.failed("No cache owner was identified.") }
            let running=await processes()
            guard !ProcessOwners.isRunning(spec.processes,in:running) else { throw CommandError.failed("The owning tool is now running. Close it and scan again.") }
            let attrs=try FileManager.default.attributesOfItem(atPath:finding.path)
            guard finding.fileIdentity != nil, finding.modifiedAt != nil,
                  (attrs[.systemFileNumber] as? NSNumber)?.uint64Value == finding.fileIdentity,
                  attrs[.modificationDate] as? Date == finding.modifiedAt else { throw CommandError.failed("The folder changed since the scan. Scan again before removal.") }
            let destination = try trash(URL(fileURLWithPath:finding.path))
            return OperationRecord(title:finding.title,outcome:"Moved to Trash",detail:"\(finding.path)\nRestore from Finder’s Trash if needed. Disk space is not reclaimed until Trash is emptied.",recoveryPath:destination?.path)
        } catch { return OperationRecord(title:finding.title,outcome:"Skipped",detail:error.localizedDescription) }
    }
}
