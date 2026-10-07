import Foundation

public struct CacheSpec: Sendable {
    public let title: String, tool: String, relativePath: String, consequence: String
    public let processes: [String]
}
public enum CacheCatalog {
    public static let specs: [CacheSpec] = [
        .init(title:"Go build cache",tool:"Go",relativePath:"Library/Caches/go-build",consequence:"The next Go build recompiles cached output.",processes:["go","compile","link","golangci-lint"]),
        .init(title:"npm package downloads",tool:"Node.js",relativePath:".npm/_cacache",consequence:"npm downloads packages again. Offline installs may fail.",processes:["node","npm","pnpm","yarn"]),
        .init(title:"pip package downloads",tool:"Python",relativePath:"Library/Caches/pip",consequence:"pip downloads packages again. Installed environments stay intact.",processes:["pip","pip3","python","python3","uv"]),
        .init(title:"uv package cache",tool:"Python",relativePath:".cache/uv",consequence:"uv recreates downloaded and compiled dependencies.",processes:["uv","python","python3"]),
        .init(title:"Cargo package archives",tool:"Rust",relativePath:".cargo/registry/cache",consequence:"Cargo downloads archived packages again. Registry source remains.",processes:["cargo","rustc"]),
        .init(title:"Gradle cache",tool:"Java & Kotlin",relativePath:".gradle/caches",consequence:"Gradle downloads dependencies and rebuilds caches. Offline builds may fail.",processes:["java","gradle","gradlew","kotlin"]),
        .init(title:"Xcode derived data",tool:"Swift & Objective-C",relativePath:"Library/Developer/Xcode/DerivedData",consequence:"Xcode rebuilds compiled output and indexes. Archives and signing keys remain.",processes:["Xcode","swift","swiftc","clang","xcodebuild","SourceKitService"]),
        .init(title:"NuGet HTTP cache",tool:".NET",relativePath:".local/share/NuGet/http-cache",consequence:"NuGet fetches package metadata and downloads again.",processes:["dotnet","NuGet"]),
        .init(title:"Composer package downloads",tool:"PHP",relativePath:"Library/Caches/composer",consequence:"Composer downloads dependencies again. Project files remain.",processes:["php","composer"]),
        .init(title:"Homebrew downloads",tool:"Homebrew",relativePath:"Library/Caches/Homebrew/downloads",consequence:"Homebrew downloads installation packages again.",processes:["brew","ruby"])
    ]
    public static func spec(for path: String, home: URL) -> CacheSpec? {
        specs.first { home.appendingPathComponent($0.relativePath).standardizedFileURL.path == URL(fileURLWithPath:path).standardizedFileURL.path }
    }
}
public struct ScanResult: Sendable { public var findings: [Finding]; public var notices: [String] }
public enum ProcessOwners {
    public static func isRunning(_ owners:[String],in processes:Set<String>)->Bool {
        func normalized(_ name:String)->String {
            let base=URL(fileURLWithPath:name).lastPathComponent.lowercased()
            return base.replacingOccurrences(of:"[0-9.]+$",with:"",options:.regularExpression)
        }
        let active=Set(processes.map(normalized))
        return owners.contains { active.contains(normalized($0)) }
    }
}
public final class InventoryService: Sendable {
    private let runner:any CommandExecuting
    private let locate:@Sendable (String)->String?
    public init(runner:any CommandExecuting=CommandRunner(),locate:@escaping @Sendable (String)->String? = {CommandRunner.locate($0)}) { self.runner=runner;self.locate=locate }
    public func scan(home: URL = FileManager.default.homeDirectoryForCurrentUser, roots: [String], exclusions: Set<String>, budget:TimeInterval=60, progress:@Sendable (String) async -> Void = { _ in }) async -> ScanResult {
        var findings=[Finding](), notices=[String]()
        let deadline=Date().addingTimeInterval(budget)
        func finish() -> ScanResult {
            if Date() >= deadline { notices.append("The scan reached its time budget. Results are partial; narrow the project roots and scan again for more coverage.") }
            var seen=Set<String>()
            return ScanResult(findings:findings.filter { seen.insert(URL(fileURLWithPath:$0.path).standardizedFileURL.path).inserted },notices:Array(Set(notices)).sorted())
        }
        let running=await runningProcesses()
        for spec in CacheCatalog.specs {
            if Date() >= deadline { return finish() }
            await progress("Inspecting " + spec.title + "…")
            let url=home.appendingPathComponent(spec.relativePath)
            guard FileManager.default.fileExists(atPath:url.path), !exclusions.contains(url.path) else { continue }
            let attrs=try? FileManager.default.attributesOfItem(atPath:url.path)
            let blocked=ProcessOwners.isRunning(spec.processes,in:running) ? "The owning tool is running. Close it, then scan again." : nil
            let measurement=await size(url.path)
            let safety=CleanupPolicy.validate(path:url.path,home:home)
            findings.append(Finding(title:spec.title,tool:spec.tool,path:url.path,bytes:measurement,group:.caches,consequence:spec.consequence,blockedReason:safety ?? blocked ?? (measurement == nil ? "The folder could not be measured." : nil),modifiedAt:attrs?[.modificationDate] as? Date,fileIdentity:(attrs?[.systemFileNumber] as? NSNumber)?.uint64Value))
        }
        // A missing engine must be shown instead of silently inventing an empty inventory.
        for tool in ["docker","podman"] {
            if Date() >= deadline { return finish() }
            await progress("Inspecting " + tool.capitalized + " connection…")
            let path=tool+"://current-connection"
            guard !exclusions.contains(path),let binary=locate(tool) else { continue }
            let r=try? await runner.run(binary,["system","df","--format","json"],timeout:15)
            if let r, r.succeeded {
                let counts=String(r.stdout.prefix(6000))
                findings.append(Finding(title:"\(tool.capitalized) storage",tool:tool.capitalized,path:path,bytes:nil,group:.containers,consequence:"Images, build caches, containers and volumes require engine-specific reference checks. Shared layers and virtual-machine disks have different accounting.",blockedReason:"Inspection only. Container deletion is not enabled in this first build.",engineReport:counts))
            } else { notices.append("\(tool.capitalized) is installed but its current connection is unavailable. No machine was started.") }
        }
        for tool in ["colima","limactl","nerdctl"] where locate(tool) != nil { notices.append("\(tool) was found. Inspect its underlying engine through Docker or Podman where configured; additional contexts are not yet scanned.") }
        var seenRepos=Set<String>()
        for root in roots {
            if Date() >= deadline { return finish() }
            let rootURL=URL(fileURLWithPath:root).standardizedFileURL
            guard FileManager.default.fileExists(atPath:rootURL.path) else { notices.append("Scan root unavailable: \(root)"); continue }
            let discovery=findRepositories(rootURL,limit:60,deadline:deadline)
            let repositories=discovery.repositories;notices.append(contentsOf:discovery.notices)
            if repositories.count == 60 { notices.append("Repository discovery reached its 60-repository limit under \(root). Narrow this root for a complete scan.") }
            for repo in repositories where seenRepos.insert(repo.path).inserted {
                if Date() >= deadline { return finish() }
                await progress("Inspecting project " + repo.lastPathComponent + "…")
                guard let git=locate("git") else { notices.append("Git was not found. Project worktrees could not be inspected.");continue }
                let result=try? await runner.run(git,["-C",repo.path,"worktree","list","--porcelain","-z"],timeout:8)
                guard let result, result.succeeded else { notices.append("Could not inspect Git worktrees under \(repo.path)."); continue }
                for worktree in WorktreeParser.parse(result.stdout) where worktree.path != repo.path && !exclusions.contains(worktree.path) {
                    if Date() >= deadline { return finish() }
                    let status=try? await runner.run(git,["-C",worktree.path,"status","--porcelain=v1","-z","--untracked-files=all"],timeout:8)
                    let dirty=status == nil || status?.succeeded == false || !(status?.stdout.isEmpty ?? true)
                    findings.append(Finding(title:URL(fileURLWithPath:worktree.path).lastPathComponent,tool:"Git",path:worktree.path,bytes:nil,group:.projects,consequence:"\(dirty ? "Changes, untracked files, or an unavailable checkout were detected." : "The checkout appears clean.") Branch: \(worktree.branch ?? "detached"). Active ownership, ignored files and unique commits still need review.",blockedReason:worktree.locked ? "Worktree is locked." : "Inspection only. Worktree removal is not enabled."))
                }
                for name in ["target","node_modules",".next",".venv",".build","dist"] {
                    if Date() >= deadline { return finish() }
                    let url=repo.appendingPathComponent(name)
                    guard FileManager.default.fileExists(atPath:url.path), !exclusions.contains(url.path) else { continue }
                    findings.append(Finding(title:"\(repo.lastPathComponent) / \(name)",tool:"Project artifacts",path:url.path,bytes:await size(url.path),group:.projects,consequence:"Inspect the project’s manifests and version-controlled files before removing this directory. Its name alone does not establish that it is disposable.",blockedReason:"Inspection only. Project artifact removal needs ownership checks."))
                }
            }
        }
        return finish()
    }
    public func size(_ path:String) async -> Int64? {
        guard let result=try? await runner.run("/usr/bin/du",["-sk",path],timeout:15),result.succeeded,
              let first=result.stdout.split(separator:"\t").first,let count=Int64(first.trimmingCharacters(in:.whitespacesAndNewlines)) else { return nil }
        return count*1024
    }
    public func runningProcesses() async -> Set<String> {
        guard let text=try? await runner.checked("/bin/ps",["-axo","comm="],timeout:5) else { return Set(CacheCatalog.specs.flatMap(\.processes)) }
        return Set(text.split(separator:"\n").map { URL(fileURLWithPath:String($0).trimmingCharacters(in:.whitespaces)).lastPathComponent })
    }
    private func findRepositories(_ root:URL,limit:Int,deadline:Date) -> (repositories:[URL],notices:[String]) {
        var result=[URL](),queue=[(root,0)],notices=[String]()
        while !queue.isEmpty && result.count<limit && Date()<deadline {
            let (url,depth)=queue.removeFirst()
            if FileManager.default.fileExists(atPath:url.appendingPathComponent(".git").path) { result.append(url); continue }
            guard depth<3 else {continue}
            do {
                let children=try FileManager.default.contentsOfDirectory(at:url,includingPropertiesForKeys:[.isDirectoryKey,.isSymbolicLinkKey],options:.skipsHiddenFiles)
                for child in children.sorted(by:{$0.path<$1.path}) where !["node_modules","vendor","target",".build"].contains(child.lastPathComponent) {
                    do {
                        let values=try child.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
                        if values.isDirectory == true && values.isSymbolicLink != true {
                            guard queue.count<4000 else {notices.append("Repository discovery reached its directory limit under \(root.path). Coverage is partial.");continue}
                            queue.append((child,depth+1))
                        }
                    } catch { notices.append("Could not inspect \(child.path): \(error.localizedDescription)") }
                }
            } catch { notices.append("Could not read scan directory \(url.path): \(error.localizedDescription)") }
            }
        return (result,notices)
    }
}
public struct Worktree: Sendable { public var path:String; public var branch:String?; public var locked:Bool }
public enum WorktreeParser {
    public static func parse(_ text:String)->[Worktree] {
        var output=[Worktree](),current:Worktree?
        for field in text.split(separator:"\0",omittingEmptySubsequences:false).map(String.init) {
            if field.hasPrefix("worktree ") { if let c=current { output.append(c) }; current=Worktree(path:String(field.dropFirst(9)),branch:nil,locked:false) }
            else if field.hasPrefix("branch ") { current?.branch=String(field.dropFirst(7)) }
            else if field=="locked" || field.hasPrefix("locked ") { current?.locked=true }
            else if field.isEmpty,let c=current { output.append(c);current=nil }
        }
        if let c=current { output.append(c) }; return output
    }
}
public enum CleanupPolicy {
    public static func validate(path:String,home:URL)->String? {
        let url=URL(fileURLWithPath:path).standardizedFileURL
        guard CacheCatalog.spec(for:url.path,home:home) != nil else { return "This path is not an approved cache location." }
        guard url.resolvingSymlinksInPath().path == url.path else { return "Symlinked cache locations are inspection-only." }
        guard url.path.hasPrefix(home.standardizedFileURL.path+"/") else { return "The cache is outside the home directory." }
        return nil
    }
}
