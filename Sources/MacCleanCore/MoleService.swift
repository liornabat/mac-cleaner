import Foundation

public final class MoleService: Sendable {
    private let runner = CommandRunner()
    public init() {}
    public func detect(customPath: String? = nil) async -> EngineInfo {
        guard let path = customPath ?? CommandRunner.locate("mo") else { return EngineInfo() }
        do {
            let output = try await runner.checked(path, ["--version"], timeout: 10)
            guard let version = Self.parseVersion(output) else { return EngineInfo(path: path, error: "The executable did not identify itself as Mole.") }
            let analysisHelp=try await runner.checked(path,["analyze","--help"],timeout:10)
            let statusHelp=try await runner.checked(path,["status","--help"],timeout:10)
            guard analysisHelp.contains("--json"), statusHelp.contains("--json") else { return EngineInfo(path:path,version:version,error:"This Mole version does not support the structured reads required by MacClean.") }
            let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            let homebrew = resolved.contains("/Cellar/mole/")
            return EngineInfo(path:path,version:version,homebrew:homebrew)
        } catch { return EngineInfo(path:path,error:error.localizedDescription) }
    }
    public static func parseVersion(_ text: String) -> String? {
        guard let line=text.split(separator:"\n").first(where:{$0.hasPrefix("Mole version ")}) else { return nil }
        let version=String(line.dropFirst("Mole version ".count)).trimmingCharacters(in:.whitespacesAndNewlines)
        return Versions.isNewer(version,than:version) == nil ? nil : version
    }
    public func latestVersion() async throws -> String {
        var request=URLRequest(url:URL(string:"https://formulae.brew.sh/api/formula/mole.json")!)
        request.timeoutInterval=20; request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data,response)=try await URLSession.shared.data(for:request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let object=try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let versions=object["versions"] as? [String:Any], let version=versions["stable"] as? String else { throw CommandError.failed("Homebrew’s release information could not be read. The latest version remains unknown.") }
        return version
    }
    public func analyze(_ info: EngineInfo, path: String) async throws -> Analysis {
        guard info.ready, let binary=info.path else { throw CommandError.failed("Install or verify Mole first.") }
        let output=try await runner.checked(binary,["analyze","--json",path],timeout:120)
        return try JSONDecoder().decode(Analysis.self,from:Data(output.utf8))
    }
    public func status(_ info: EngineInfo) async throws -> SystemSnapshot {
        guard info.ready, let binary=info.path else { throw CommandError.failed("Install or verify Mole first.") }
        let output=try await runner.checked(binary,["status","--json"],timeout:30)
        return try JSONDecoder().decode(SystemSnapshot.self,from:Data(output.utf8))
    }
    public func cleanupPreview(_ info: EngineInfo) async throws -> String {
        guard info.ready, let binary=info.path else { throw CommandError.failed("Install or verify Mole first.") }
        let result=try await runner.run(binary,["clean","--dry-run"],timeout:180,environment:["MOLE_DRY_RUN":"1"])
        let clean=(result.stdout+"\n"+result.stderr).replacingOccurrences(of:"\u{001B}\\[[0-?]*[ -/]*[@-~]",with:"",options:.regularExpression)
        if result.timedOut { return clean + "\nPreview timed out; the report may be incomplete. No cleanup was requested." }
        if !result.succeeded { return clean + "\nPreview returned an error; the report may be incomplete." }
        return clean
    }
    public func installOrUpgrade(_ info: EngineInfo) async throws -> String {
        guard let brew=CommandRunner.locate("brew") else { throw CommandError.failed("Homebrew was not found. Install Mole using its official instructions, then detect again.") }
        guard info.path == nil || (info.ready && info.homebrew) else { throw CommandError.failed("This installation is not managed by Homebrew. Use its existing installer to update it.") }
        let result=try await runner.run(brew,[info.path == nil ? "install" : "upgrade","mole"],timeout:600)
        guard result.succeeded else { throw CommandError.failed(result.timedOut ? "Package-manager operation timed out. Detect the engine again before retrying." : String((result.stderr+result.stdout).suffix(6000))) }
        return result.stdout+result.stderr
    }
}
