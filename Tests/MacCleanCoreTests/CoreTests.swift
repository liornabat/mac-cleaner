import Testing
import Foundation
@testable import MacCleanCore

@Suite struct CoreTests {
    @Test func testVersionOrderingAndUnknownVersion() {
        expectEqual(Versions.isNewer("1.100.0",than:"1.56.0"),true)
        expectEqual(Versions.isNewer("v1.56.0",than:"1.56"),false)
        expectNil(Versions.isNewer("nightly",than:"1.56.0"))
        expectNil(Versions.isNewer("1.-56.0",than:"1.56.0"))
        expectEqual(MoleService.parseVersion("Mole version 1.56.0\nmacOS: 27.0"),"1.56.0")
        expectNil(MoleService.parseVersion("Other app version 1.56.0"))
    }
    @Test func testWorktreeParserPreservesSpacesAndNewlines() {
        let text="worktree /tmp/repo\0HEAD abc\0branch refs/heads/main\0\0worktree /tmp/a path\nname\0HEAD def\0locked active owner\0\0"
        let parsed=WorktreeParser.parse(text)
        expectEqual(parsed.count,2)
        expectEqual(parsed[1].path,"/tmp/a path\nname")
        expectTrue(parsed[1].locked)
        expectEqual(parsed[0].branch,"refs/heads/main")
    }
    @Test func testUnapprovedAndSymlinkedCachePathsAreDenied() throws {
        let temp=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:temp) }
        expectNotNil(CleanupPolicy.validate(path:temp.path,home:temp))
        expectNotNil(CleanupPolicy.validate(path:temp.appendingPathComponent("Documents").path,home:temp))
        let cache=temp.appendingPathComponent("Library/Caches/go-build")
        try FileManager.default.createDirectory(at:cache.deletingLastPathComponent(),withIntermediateDirectories:true)
        let source=temp.appendingPathComponent("source")
        try FileManager.default.createDirectory(at:source,withIntermediateDirectories:true)
        try FileManager.default.createSymbolicLink(at:cache,withDestinationURL:source)
        expectNotNil(CleanupPolicy.validate(path:cache.path,home:temp))
    }
    @Test func testUnknownSizeCannotBecomeCleanupAction() {
        let item=Finding(title:"cache",tool:"Go",path:"/tmp/not-allowed",bytes:nil,group:.caches,consequence:"rebuild")
        expectFalse(item.canClean)
    }
    @Test func testProtectedFindingDoesNotDeleteData() async throws {
        let temp=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("source changes".utf8).write(to:temp)
        defer { try? FileManager.default.removeItem(at:temp) }
        let item=Finding(title:"worktree",tool:"Git",path:temp.path,bytes:14,group:.projects,consequence:"data",blockedReason:"Protected")
        let result=await CleanupService().moveToTrash(item)
        expectEqual(result.outcome,"Skipped")
        expectTrue(FileManager.default.fileExists(atPath:temp.path))
    }
    @Test func testNonCachePathCannotBeTrashedEvenWhenMarkedSelectable() async throws {
        let temp=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("keep".utf8).write(to:temp)
        defer { try? FileManager.default.removeItem(at:temp) }
        let item=Finding(title:"cache",tool:"Go",path:temp.path,bytes:4,group:.caches,consequence:"rebuild")
        let result=await CleanupService().moveToTrash(item)
        expectEqual(result.outcome,"Skipped")
        expectTrue(FileManager.default.fileExists(atPath:temp.path))
    }
    @Test func testCommandCapturesOutputAndFailure() async throws {
        let runner=CommandRunner()
        let ok=try await runner.run("/usr/bin/printf",["hello"])
        expectTrue(ok.succeeded);expectEqual(ok.stdout,"hello")
        let failure=try await runner.run("/usr/bin/false",[])
        expectFalse(failure.succeeded)
    }
    @Test func testTimeoutDoesNotHangOnFullOutputPipe() async throws {
        let before=Date()
        let result=try await CommandRunner().run("/usr/bin/yes",[],timeout:0.1)
        expectTrue(result.timedOut)
        expectLessThan(Date().timeIntervalSince(before),3)
    }
    @Test func testAnalysisParsing() throws {
        let json=#"{"path":"/tmp","entries":[{"name":"a","path":"/tmp/a","size":123,"is_dir":false}],"total_size":123}"#
        let parsed=try JSONDecoder().decode(Analysis.self,from:Data(json.utf8))
        expectEqual(parsed.entries.first?.size,123)
    }
}

private func expectEqual<T:Equatable>(_ lhs:T,_ rhs:T) { #expect(lhs == rhs) }
private func expectTrue(_ value:Bool) { #expect(value) }
private func expectFalse(_ value:Bool) { #expect(!value) }
private func expectNil<T>(_ value:T?) { #expect(value == nil) }
private func expectNotNil<T>(_ value:T?) { #expect(value != nil) }
private func expectLessThan<T:Comparable>(_ lhs:T,_ rhs:T) { #expect(lhs < rhs) }

@Suite struct ScanBoundaryTests {
    @Test func scanBudgetProducesExplicitPartialNotice() async {
        let result=await InventoryService().scan(roots:[],exclusions:[],budget:0)
        #expect(result.findings.isEmpty)
        #expect(result.notices.contains(where:{$0.contains("partial")}))
    }
    @Test func approvedCacheCannotBeChangedBetweenScanAndReview() async throws {
        let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        let cache=home.appendingPathComponent(".local/share/NuGet/http-cache")
        try FileManager.default.createDirectory(at:cache,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:home) }
        let attrs=try FileManager.default.attributesOfItem(atPath:cache.path)
        let finding=Finding(title:"NuGet",tool:".NET",path:cache.path,bytes:100,group:.caches,consequence:"download again",modifiedAt:Date(timeIntervalSince1970:0),fileIdentity:(attrs[.systemFileNumber] as? NSNumber)?.uint64Value)
        let result=await CleanupService().moveToTrash(finding,home:home)
        #expect(result.outcome == "Skipped")
        #expect(FileManager.default.fileExists(atPath:cache.path))
    }
}
