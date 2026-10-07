import Foundation
import Testing
@testable import MacCleanCore

actor FixtureCommands:CommandExecuting {
    struct Call:Sendable { let executable:String;let arguments:[String];let environment:[String:String] }
    private(set) var calls=[Call]()
    let respond:@Sendable (String,[String])->CommandResult
    init(_ respond:@escaping @Sendable (String,[String])->CommandResult) { self.respond=respond }
    func run(_ executable:String,_ arguments:[String],timeout:TimeInterval,environment:[String:String]) async throws -> CommandResult {
        calls.append(Call(executable:executable,arguments:arguments,environment:environment))
        return respond(executable,arguments)
    }
}
private func fixtureHome() throws -> URL {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent("macclean-tests-"+UUID().uuidString).resolvingSymlinksInPath()
    try FileManager.default.createDirectory(at:home,withIntermediateDirectories:true)
    return home
}

@Suite struct ProviderTests {
    @Test func missingEngineDoesNotRunAnyExecutable() async {
        let runner=FixtureCommands { _,_ in CommandResult(stdout:"") }
        let info=await MoleService(runner:runner,locate:{_ in nil}).detect()
        #expect(!info.ready)
        #expect(await runner.calls.isEmpty)
    }
    @Test func incompatibleHomebrewEngineRemainsRepairable() async throws {
        let runner=FixtureCommands { _,args in CommandResult(stdout:args == ["--version"] ? "Mole version 1.40.0" : "legacy help") }
        let service=MoleService(runner:runner,locate:{name in name == "mo" ? "/opt/homebrew/Cellar/mole/1.40.0/bin/mo" : "/fixture/brew"})
        let info=await service.detect()
        #expect(!info.ready && info.homebrew)
        _ = try await service.installOrUpgrade(info)
        #expect(await runner.calls.last?.arguments == ["upgrade","mole"])
    }
    @Test func customEngineDoesNotUseHomebrewUpgrade() async {
        let runner=FixtureCommands { _,_ in CommandResult(stdout:"") }
        let service=MoleService(runner:runner,locate:{_ in "/fixture/brew"})
        do { _ = try await service.installOrUpgrade(EngineInfo(path:"/custom/mo",version:"1.56.0"));Issue.record("Custom installation was accepted for Homebrew upgrade") } catch {}
        #expect(await runner.calls.isEmpty)
    }
    @Test func installationUsesOnlyTheExistingPackageManager() async throws {
        let runner=FixtureCommands { _,_ in CommandResult(stdout:"installed") }
        _ = try await MoleService(runner:runner,locate:{_ in "/fixture/brew"}).installOrUpgrade(EngineInfo())
        #expect(await runner.calls.first?.arguments == ["install","mole"])
        do { _ = try await MoleService(runner:runner,locate:{_ in nil}).installOrUpgrade(EngineInfo());Issue.record("Missing Homebrew was accepted") } catch {}
        #expect(await runner.calls.count == 1)
    }
    @Test func packageFailureAndTimeoutAreReported() async {
        for result in [CommandResult(stdout:"",stderr:"package failure",exitCode:1),CommandResult(stdout:"",timedOut:true)] {
            let runner=FixtureCommands { _,_ in result }
            do { _ = try await MoleService(runner:runner,locate:{_ in "/fixture/brew"}).installOrUpgrade(EngineInfo());Issue.record("Failed installation was reported as successful") } catch { #expect(!error.localizedDescription.isEmpty) }
        }
    }
    @Test func structuredReadsUseLiteralPathArguments() async throws {
        let runner=FixtureCommands { _,args in
            CommandResult(stdout:args.first == "analyze" ? #"{"path":"/fixture","entries":[],"total_size":0}"# : #"{"cpu":{"usage":2.5},"memory":{"used":4096,"total":8192,"used_percent":50},"disks":[{"mount":"/","total":100,"used":20}],"uptime":"1d 2h"}"#)
        }
        let service=MoleService(runner:runner)
        let engine=EngineInfo(path:"/fixture/mo",version:"1.56.0")
        let path="/fixture/a folder; $(do-not-execute)"
        let analysis=try await service.analyze(engine,path:path)
        let snapshot=try await service.status(engine)
        #expect(analysis.entries.isEmpty && snapshot.memory.used == 4096)
        #expect(await runner.calls.first?.arguments == ["analyze","--json",path])
        #expect(await runner.calls.last?.arguments == ["status","--json"])
    }
    @Test func cleanupPreviewNeverRequestsDestructiveCleaning() async throws {
        let runner=FixtureCommands { _,args in args.contains("--help") ? CommandResult(stdout:"--dry-run") : CommandResult(stdout:"\u{001B}[31mpreview\u{001B}[0m",timedOut:true) }
        let report=try await MoleService(runner:runner).cleanupPreview(EngineInfo(path:"/fixture/mo",version:"1.56.0"))
        #expect(report.contains("incomplete") && !report.contains("\u{001B}"))
        #expect(await runner.calls.last?.arguments == ["clean","--dry-run"])
        #expect(await runner.calls.last?.environment["MOLE_DRY_RUN"] == "1")
    }
    @Test func unsupportedCleanupPreviewNeverStartsCleaning() async {
        let runner=FixtureCommands { _,_ in CommandResult(stdout:"legacy cleanup help") }
        do { _ = try await MoleService(runner:runner).cleanupPreview(EngineInfo(path:"/fixture/mo",version:"1.40.0"));Issue.record("Unsupported preview started") } catch {}
        #expect(await runner.calls.count == 1)
        #expect(await runner.calls.first?.arguments == ["clean","--help"])
    }
    @Test func processOwnerMatchingHandlesFrameworkAndVersionedInterpreters() {
        for name in ["Python","python3.14","/Library/Frameworks/Python.framework/Versions/3.14/Python","pip3.14"] { #expect(ProcessOwners.isRunning(["python","pip"],in:[name])) }
        #expect(!ProcessOwners.isRunning(["python"],in:["python-helper","not-python"]))
    }
    @Test func containerExclusionSurvivesScanAndRestoration() async throws {
        let home=try fixtureHome();defer{try? FileManager.default.removeItem(at:home)}
        let runner=FixtureCommands { _,_ in CommandResult(stdout:"[]") }
        let service=InventoryService(runner:runner,locate:{name in name == "docker" ? "/fixture/docker" : nil})
        let hidden=await service.scan(home:home,roots:[],exclusions:["docker://current-connection"])
        #expect(hidden.findings.isEmpty)
        #expect(await runner.calls.allSatisfy{$0.executable != "/fixture/docker"})
        let restored=await service.scan(home:home,roots:[],exclusions:[])
        #expect(restored.findings.count == 1 && restored.findings.first?.canClean == false)
    }
    @Test func unavailableContainerAndDirectoryAreExplicit() async throws {
        let home=try fixtureHome();defer{try? FileManager.default.removeItem(at:home)}
        let file=home.appendingPathComponent("not-a-directory");try Data("keep".utf8).write(to:file)
        let runner=FixtureCommands { _,_ in CommandResult(stdout:"",stderr:"unavailable",exitCode:1) }
        let result=await InventoryService(runner:runner,locate:{name in name == "podman" ? "/fixture/podman" : nil}).scan(home:home,roots:[file.path],exclusions:[])
        #expect(result.notices.contains{$0.contains("Podman") && $0.contains("unavailable")})
        #expect(result.notices.contains{$0.contains("Could not read scan directory")})
    }
    @Test func repeatedWorktreeRegistrationsProduceUniqueFindings() async throws {
        let home=try fixtureHome();defer{try? FileManager.default.removeItem(at:home)}
        let root=home.appendingPathComponent("projects")
        let repos=[root.appendingPathComponent("main"),root.appendingPathComponent("first"),root.appendingPathComponent("second")]
        for repo in repos { try FileManager.default.createDirectory(at:repo.appendingPathComponent(".git"),withIntermediateDirectories:true) }
        let listing=repos.map{"worktree \($0.path)\0HEAD abc\0branch refs/heads/main\0\0"}.joined()
        let runner=FixtureCommands { _,args in CommandResult(stdout:args.contains("worktree") ? listing : "") }
        let result=await InventoryService(runner:runner,locate:{name in name == "git" ? "/fixture/git" : nil}).scan(home:home,roots:[root.path,root.path],exclusions:[])
        #expect(result.findings.count == 3)
        #expect(Set(result.findings.map(\.id)).count == result.findings.count)
    }
    @Test func cleanupSuccessAndFailurePreserveRecoveryAndReportOutcomes() async throws {
        let home=try fixtureHome();defer{try? FileManager.default.removeItem(at:home)}
        let cache=home.appendingPathComponent(".local/share/NuGet/http-cache")
        try FileManager.default.createDirectory(at:cache,withIntermediateDirectories:true)
        try Data("fixture cache".utf8).write(to:cache.appendingPathComponent("payload"))
        let attributes=try FileManager.default.attributesOfItem(atPath:cache.path)
        let finding=Finding(title:"fixture",tool:".NET",path:cache.path,bytes:13,group:.caches,consequence:"download again",modifiedAt:attributes[.modificationDate] as? Date,fileIdentity:(attributes[.systemFileNumber] as? NSNumber)?.uint64Value)
        let failure=await CleanupService(processes:{[]},trash:{_ in throw CommandError.failed("Fixture Trash unavailable")}).moveToTrash(finding,home:home)
        #expect(failure.outcome == "Skipped" && FileManager.default.fileExists(atPath:cache.path))
        let trash=home.appendingPathComponent("fixture-trash")
        let success=await CleanupService(processes:{[]},trash:{url in try FileManager.default.moveItem(at:url,to:trash);return trash}).moveToTrash(finding,home:home)
        #expect(success.outcome == "Moved to Trash")
        #expect(!FileManager.default.fileExists(atPath:cache.path))
        #expect(try String(contentsOf:trash.appendingPathComponent("payload"),encoding:.utf8) == "fixture cache")
    }
    @Test func activeVersionedPythonBlocksTrashAfterReview() async throws {
        let home=try fixtureHome();defer{try? FileManager.default.removeItem(at:home)}
        let cache=home.appendingPathComponent("Library/Caches/pip")
        try FileManager.default.createDirectory(at:cache,withIntermediateDirectories:true)
        let attrs=try FileManager.default.attributesOfItem(atPath:cache.path)
        let finding=Finding(title:"pip",tool:"Python",path:cache.path,bytes:1,group:.caches,consequence:"download again",modifiedAt:attrs[.modificationDate] as? Date,fileIdentity:(attrs[.systemFileNumber] as? NSNumber)?.uint64Value)
        let result=await CleanupService(processes:{["Python3.14"]},trash:{_ in Issue.record("Active cache reached Trash backend");return nil}).moveToTrash(finding,home:home)
        #expect(result.outcome == "Skipped" && FileManager.default.fileExists(atPath:cache.path))
    }
    @Test func nativeTrashMovesOnlyTheFixtureAndAllowsRecovery() async throws {
        let home=try fixtureHome();defer{try? FileManager.default.removeItem(at:home)}
        let cache=home.appendingPathComponent(".local/share/NuGet/http-cache")
        try FileManager.default.createDirectory(at:cache,withIntermediateDirectories:true)
        try Data("disposable verification fixture".utf8).write(to:cache.appendingPathComponent("fixture.txt"))
        let attrs=try FileManager.default.attributesOfItem(atPath:cache.path)
        let finding=Finding(title:"verification fixture",tool:".NET",path:cache.path,bytes:30,group:.caches,consequence:"fixture only",modifiedAt:attrs[.modificationDate] as? Date,fileIdentity:(attrs[.systemFileNumber] as? NSNumber)?.uint64Value)
        let record=await CleanupService(processes:{[]}).moveToTrash(finding,home:home)
        #expect(record.outcome == "Moved to Trash",Comment(rawValue:record.detail))
        let recovery=try #require(record.recoveryPath)
        defer { try? FileManager.default.removeItem(atPath:recovery) }
        #expect(!FileManager.default.fileExists(atPath:cache.path))
        try FileManager.default.moveItem(at:URL(fileURLWithPath:recovery),to:cache)
        #expect(try String(contentsOf:cache.appendingPathComponent("fixture.txt"),encoding:.utf8) == "disposable verification fixture")
    }
}
