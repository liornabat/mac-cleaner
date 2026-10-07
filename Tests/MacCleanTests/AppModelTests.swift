import Foundation
import Testing
@testable import MacClean
@testable import MacCleanCore

private actor ModelCommands:CommandExecuting {
    private(set) var calls=[(String,[String])]()
    let packageFails:Bool
    let stableUpgradePath:String?
    var upgraded=false
    init(packageFails:Bool=false,stableUpgradePath:String?=nil) { self.packageFails=packageFails;self.stableUpgradePath=stableUpgradePath }
    func run(_ executable:String,_ arguments:[String],timeout:TimeInterval,environment:[String:String]) async throws -> CommandResult {
        calls.append((executable,arguments))
        if arguments == ["--version"] { return CommandResult(stdout:upgraded && executable == stableUpgradePath ? "Mole version 1.58.0" : "Mole version 1.56.0") }
        if arguments.contains("--help") { return CommandResult(stdout:"--json --dry-run") }
        if arguments.first == "install" || arguments.first == "upgrade" { upgraded = !packageFails;return CommandResult(stdout:packageFails ? "" : "fixture package completed",stderr:packageFails ? "fixture package failed" : "",exitCode:packageFails ? 1 : 0) }
        if arguments.first == "status" { return CommandResult(stdout:#"{"cpu":{"usage":2},"memory":{"used":1,"total":2,"used_percent":50},"disks":[],"uptime":"2h"}"#) }
        if arguments.first == "analyze" { return CommandResult(stdout:#"{"path":"/fixture","entries":[],"total_size":0}"#) }
        return CommandResult(stdout:arguments.first == "clean" ? "fixture preview" : "")
    }
}

@Suite @MainActor struct AppModelTests {
    func home() throws -> URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("macclean-model-tests-"+UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
        return url
    }
    private func service(_ runner:ModelCommands,version:String="1.58.0") -> MoleService {
        MoleService(runner:runner,locate:{name in name == "mo" ? "/fixture/mo" : "/fixture/brew"},versionLoader:{version})
    }
    func idle(_ model:AppModel) async throws {
        let deadline=Date().addingTimeInterval(3)
        while model.busy && Date()<deadline { try await Task.sleep(nanoseconds:10_000_000) }
        #expect(!model.busy)
    }
    @Test func customExecutablePersistsAndDetectAgainKeepsIt() async throws {
        let temp=try home();defer{try? FileManager.default.removeItem(at:temp)}
        let runner=ModelCommands(),mole=service(ModelCommands())
        let model=AppModel(home:temp,mole:service(runner))
        model.latestVersion="old metadata";model.selectEngine(path:"/fixture/custom/mo")
        try await idle(model)
        #expect(model.engine.path == "/fixture/custom/mo" && model.latestVersion == nil)
        model.detect();try await idle(model)
        #expect(model.engine.path == "/fixture/custom/mo")
        let reloaded=AppModel(home:temp,mole:mole)
        #expect(reloaded.customEnginePath == "/fixture/custom/mo")
        reloaded.useDetectedEngine();try await idle(reloaded)
        #expect(reloaded.engine.path == "/fixture/mo" && reloaded.customEnginePath == nil)
    }
    @Test func upgradingVersionedHomebrewSelectionUsesStableExecutable() async throws {
        let temp=try home();defer{try? FileManager.default.removeItem(at:temp)}
        let stable="/fixture/homebrew/bin/mo",old="/fixture/homebrew/Cellar/mole/1.56.0/bin/mo"
        let runner=ModelCommands(stableUpgradePath:stable),model=AppModel(home:temp,mole:service(runner))
        model.selectEngine(path:old);try await idle(model)
        #expect(model.engine.homebrew && model.engine.version == "1.56.0")
        model.executeEngineChange();try await idle(model)
        #expect(model.engine.path == stable && model.engine.version == "1.58.0")
        #expect(model.operations.first?.outcome == "Completed")
        #expect(AppModel(home:temp,mole:service(runner)).customEnginePath == stable)
    }
    @Test func overviewContainerNavigationSelectsContainerTab() {
        let model=AppModel(stateURL:URL(fileURLWithPath:"/nonexistent/macclean-test-state"))
        model.show(.containers)
        #expect(model.section == .storage && model.storageTab == "Containers")
        model.show(.caches);#expect(model.section == .cleanup)
        model.show(.projects);#expect(model.section == .projects)
    }
    @Test func appVersionResourceMatchesRepositoryMetadata() throws {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data=try Data(contentsOf:root.appendingPathComponent("Sources/MacClean/Resources/AppVersion.json"))
        let metadata=try JSONDecoder().decode(AppVersion.Metadata.self,from:data)
        #expect(AppVersion.load().version == metadata.version)
        #expect(AppVersion.load().build == String(metadata.build))
        #expect(AppVersion.load().display.contains("build"))
    }
    @Test func bundledBrandArtworkLoadsForDevelopment() {
        #expect(BrandAssets.icon.isValid)
        #expect(BrandAssets.icon.size.width > 0 && BrandAssets.icon.size.height > 0)
    }
    @Test func containerReportsKeepEngineValuesAndUnknownFields() {
        let lines="{\"Type\":\"Images\",\"TotalCount\":\"4\",\"Size\":\"1.2GB\"}\n{\"Type\":\"Containers\",\"TotalCount\":2,\"Active\":1}"
        let parsed=ContainerReportRow.parse(lines)
        #expect(parsed.count == 2 && parsed[0].size == "1.2GB" && parsed[0].active == "Unknown")
        #expect(parsed[1].count == "2")
        #expect(ContainerReportRow.parse("[{\"Type\":\"Images\"}]").count == 1)
        #expect(ContainerReportRow.parse("unrecognized provider output").isEmpty)
    }
    @Test func updateAvailabilityAndNetworkFailureAreExplicit() async throws {
        let temp=try home();defer{try? FileManager.default.removeItem(at:temp)}
        let runner=ModelCommands()
        let model=AppModel(home:temp,mole:service(runner))
        model.engine=EngineInfo(path:"/fixture/mo",version:"1.56.0")
        model.checkUpdates();try await idle(model)
        #expect(model.latestVersion == "1.58.0" && model.updateMessage.contains("Update available"))
        let offline=AppModel(home:temp,mole:MoleService(runner:runner,versionLoader:{throw CommandError.failed("Fixture offline")}))
        offline.latestVersion="stale";offline.checkUpdates();try await idle(offline)
        #expect(offline.latestVersion == nil && offline.updateMessage == "Latest version unknown" && offline.error == "Fixture offline")
    }
    @Test func busyStatePreventsCompetingOperations() async throws {
        let temp=try home();defer{try? FileManager.default.removeItem(at:temp)}
        let runner=ModelCommands()
        let model=AppModel(home:temp,mole:service(runner))
        model.busy=true;model.progress="existing work"
        model.detect();model.selectEngine(path:"/unexpected");model.previewMole();model.refreshStatus();model.scan();model.checkUpdates()
        #expect(await runner.calls.isEmpty)
        #expect(model.progress == "existing work" && model.customEnginePath == nil)
    }
    @Test func systemSnapshotAnalysisAndPreviewReachTheirViews() async throws {
        let temp=try home();defer{try? FileManager.default.removeItem(at:temp)}
        let runner=ModelCommands(),model=AppModel(home:temp,mole:service(ModelCommands()))
        model.engine=EngineInfo(path:"/fixture/mo",version:"1.56.0")
        model.refreshStatus();try await idle(model);#expect(model.snapshot?.uptime == "2h")
        model.analyze("/fixture");try await idle(model);#expect(model.analysis?.entries.isEmpty == true)
        model.previewMole();try await idle(model);#expect(model.moleReport.contains("fixture preview"))
        let absent=AppModel(home:temp,mole:service(runner))
        absent.refreshStatus();try await idle(absent)
        #expect(absent.error != nil && absent.snapshot == nil)
    }
    @Test func packageSuccessFailureAndHistoryArePersisted() async throws {
        let temp=try home();defer{try? FileManager.default.removeItem(at:temp)}
        let runner=ModelCommands(),model=AppModel(home:temp,mole:service(ModelCommands()))
        model.executeEngineChange();try await idle(model)
        #expect(model.engine.ready && model.operations.first?.outcome == "Completed")
        let failure=AppModel(home:temp,mole:service(ModelCommands(packageFails:true)))
        failure.engine=EngineInfo(path:"/opt/homebrew/Cellar/mole/old/bin/mo",version:"1.40.0",homebrew:true,error:"unsupported")
        failure.executeEngineChange();try await idle(failure)
        #expect(failure.operations.first?.outcome == "Failed" && failure.error != nil)
        let reload=AppModel(home:temp,mole:service(runner))
        #expect(reload.operations.count == 2)
    }
    @Test func exclusionsRootsAndLegacyStateSurviveReload() throws {
        let temp=try home();defer{try? FileManager.default.removeItem(at:temp)}
        let model=AppModel(home:temp)
        model.roots=["/fixture/projects"]
        model.appearance="Light"
        let item=Finding(title:"Docker",tool:"Docker",path:"docker://current-connection",bytes:nil,group:.containers,consequence:"inspect")
        model.findings=[item];model.exclude(item)
        #expect(model.findings.isEmpty)
        let reload=AppModel(home:temp)
        #expect(reload.roots == ["/fixture/projects"] && reload.exclusions.contains(item.path))
        #expect(reload.appearance == "Light")
        let legacy=temp.appendingPathComponent("legacy.json")
        try Data(#"{"roots":[],"exclusions":[],"operations":[]}"#.utf8).write(to:legacy)
        #expect(AppModel(stateURL:legacy,home:temp).error == nil)
    }
    @Test func unreadableStateIsReportedAndBackedUpBeforeReplacement() async throws {
        let temp=try home();defer{try? FileManager.default.removeItem(at:temp)}
        let state=temp.appendingPathComponent("state.json")
        let broken=Data("unreadable fixture state".utf8);try broken.write(to:state)
        let model=AppModel(stateURL:state,home:temp,mole:service(ModelCommands()))
        model.detect();try await idle(model)
        #expect(model.error?.contains("Saved settings") == true)
        model.persist()
        let backups=try FileManager.default.contentsOfDirectory(at:temp,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.hasPrefix("state-unreadable-")}
        #expect(backups.count == 1)
        #expect(try Data(contentsOf:backups[0]) == broken)
    }
    @Test func cleanupRequiresAcknowledgementAndRecordsPartialOutcomes() async throws {
        let temp=try home();defer{try? FileManager.default.removeItem(at:temp)}
        let cache=temp.appendingPathComponent(".local/share/NuGet/http-cache")
        try FileManager.default.createDirectory(at:cache,withIntermediateDirectories:true)
        let attrs=try FileManager.default.attributesOfItem(atPath:cache.path)
        let allowed=Finding(title:"fixture cache",tool:".NET",path:cache.path,bytes:1,group:.caches,consequence:"download",modifiedAt:attrs[.modificationDate] as? Date,fileIdentity:(attrs[.systemFileNumber] as? NSNumber)?.uint64Value)
        let protected=Finding(title:"fixture worktree",tool:"Git",path:temp.appendingPathComponent("worktree").path,bytes:1,group:.projects,consequence:"keep")
        let trash=temp.appendingPathComponent("fixture-trash")
        let model=AppModel(home:temp,cleanup:CleanupService(processes:{[]},trash:{url in try FileManager.default.moveItem(at:url,to:trash);return trash}))
        model.findings=[allowed,protected];model.selected=[allowed.id,protected.id]
        model.executeCleanup();#expect(!model.busy && FileManager.default.fileExists(atPath:cache.path))
        model.acknowledgement=true;model.executeCleanup();try await idle(model)
        #expect(Set(model.operations.map(\.outcome)) == ["Moved to Trash","Skipped"])
        #expect(model.findings.map(\.id) == [protected.id] && model.selected.isEmpty && model.section == .history)
        #expect(AppModel(home:temp).operations.count == 2)
    }
}
