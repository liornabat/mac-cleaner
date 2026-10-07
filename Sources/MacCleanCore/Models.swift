import Foundation

public enum FindingGroup: String, CaseIterable, Codable, Sendable { case caches = "Developer caches", projects = "Projects & worktrees", containers = "Containers" }
public struct Finding: Identifiable, Codable, Hashable, Sendable {
    public var id: String { path }
    public var title: String
    public var tool: String
    public var path: String
    public var bytes: Int64?
    public var group: FindingGroup
    public var consequence: String
    public var blockedReason: String?
    public var modifiedAt: Date?
    public var fileIdentity: UInt64?
    public var engineReport:String?
    public var canClean: Bool { group == .caches && blockedReason == nil && bytes != nil }
    public init(title: String, tool: String, path: String, bytes: Int64?, group: FindingGroup, consequence: String, blockedReason: String? = nil, modifiedAt: Date? = nil, fileIdentity: UInt64? = nil,engineReport:String? = nil) {
        self.title=title; self.tool=tool; self.path=path; self.bytes=bytes; self.group=group; self.consequence=consequence; self.blockedReason=blockedReason; self.modifiedAt=modifiedAt; self.fileIdentity=fileIdentity;self.engineReport=engineReport
    }
}
public struct OperationRecord: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var date = Date()
    public var title: String
    public var outcome: String
    public var detail: String
    public var recoveryPath:String?
    public init(title:String,outcome:String,detail:String,recoveryPath:String?=nil) { self.title=title;self.outcome=outcome;self.detail=detail;self.recoveryPath=recoveryPath }
}
public struct EngineInfo: Sendable {
    public var path: String?
    public var version: String?
    public var homebrew: Bool
    public var error: String?
    public var ready: Bool { path != nil && version != nil && error == nil }
    public init(path: String? = nil, version: String? = nil, homebrew: Bool = false, error: String? = nil) { self.path=path; self.version=version; self.homebrew=homebrew; self.error=error }
}
public struct Analysis: Decodable, Sendable {
    public struct Entry: Decodable, Identifiable, Sendable {
        public var id: String { path }
        public var name: String; public var path: String; public var size: Int64; public var is_dir: Bool
    }
    public var path: String; public var entries: [Entry]; public var total_size: Int64
}
public struct SystemSnapshot: Decodable, Sendable {
    public struct CPU: Decodable, Sendable { public var usage: Double }
    public struct Memory: Decodable, Sendable { public var used: Int64; public var total: Int64; public var used_percent: Double }
    public struct Disk: Decodable, Sendable { public var mount: String; public var total: Int64; public var used: Int64 }
    public var cpu: CPU; public var memory: Memory; public var disks: [Disk]; public var uptime: String
}
public enum Versions {
    public static func isNewer(_ candidate: String, than installed: String) -> Bool? {
        func components(_ s: String) -> [Int]? {
            let trimmed = s.hasPrefix("v") ? String(s.dropFirst()) : s
            let pieces = trimmed.split(separator: ".", omittingEmptySubsequences: false)
            guard pieces.count >= 2, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy{"0123456789".contains($0)} && Int($0) != nil }) else { return nil }
            return pieces.compactMap { Int($0) }
        }
        guard let a=components(candidate), let b=components(installed) else { return nil }
        for i in 0..<max(a.count,b.count) {
            let x=i<a.count ? a[i] : 0, y=i<b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
public func formatBytes(_ value: Int64?) -> String { guard let value else { return "Unknown size" }; return ByteCountFormatter.string(fromByteCount: value, countStyle: .file) }
