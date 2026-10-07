import Foundation
import Darwin

public struct CommandResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    public let timedOut: Bool
    public init(stdout:String,stderr:String="",exitCode:Int32=0,timedOut:Bool=false) { self.stdout=stdout;self.stderr=stderr;self.exitCode=exitCode;self.timedOut=timedOut }
    public var succeeded: Bool { exitCode == 0 && !timedOut }
}
public protocol CommandExecuting:Sendable {
    func run(_ executable:String,_ arguments:[String],timeout:TimeInterval,environment:[String:String]) async throws -> CommandResult
}
public extension CommandExecuting {
    func run(_ executable:String,_ arguments:[String],timeout:TimeInterval=30) async throws -> CommandResult {
        try await run(executable,arguments,timeout:timeout,environment:[:])
    }
    func checked(_ executable:String,_ arguments:[String],timeout:TimeInterval=30) async throws -> String {
        let result=try await run(executable,arguments,timeout:timeout)
        guard result.succeeded else { throw CommandError.failed(result.timedOut ? "The command timed out. Try again after checking the tool." : String((result.stderr.isEmpty ? result.stdout : result.stderr).suffix(4000))) }
        return result.stdout
    }
}
public enum CommandError: LocalizedError {
    case failed(String)
    public var errorDescription: String? { if case .failed(let message) = self { return message }; return nil }
}
/// Separate pipe readers prevent a verbose subprocess from blocking on a full pipe.
/// Commands always have a bounded lifetime and never run through a shell.
public final class CommandRunner: CommandExecuting, @unchecked Sendable {
    public init() {}
    public static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        env["NO_COLOR"] = "1"; env["TERM"] = "dumb"; env["HOMEBREW_NO_ENV_HINTS"] = "1"
        return env
    }
    public func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 30, environment: [String: String] = [:]) async throws -> CommandResult {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let process = Process(), output = Pipe(), error = Pipe()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments
                    process.environment = Self.environment.merging(environment) { _, new in new }
                    process.standardInput = FileHandle.nullDevice
                    process.standardOutput = output; process.standardError = error
                    let temp = FileManager.default.temporaryDirectory.appendingPathComponent("macclean-command-" + UUID().uuidString)
                    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
                    defer { try? FileManager.default.removeItem(at: temp) }
                    let outURL = temp.appendingPathComponent("stdout"), errURL = temp.appendingPathComponent("stderr")
                    FileManager.default.createFile(atPath: outURL.path, contents: nil)
                    FileManager.default.createFile(atPath: errURL.path, contents: nil)
                    let outFile = try FileHandle(forWritingTo: outURL), errFile = try FileHandle(forWritingTo: errURL)
                    defer { try? outFile.close(); try? errFile.close() }
                    let readers = DispatchGroup()
                    try process.run()
                    for (pipe, file) in [(output,outFile),(error,errFile)] {
                        readers.enter()
                        DispatchQueue.global(qos: .utility).async {
                            var stored=0
                            while true {
                                let data = pipe.fileHandleForReading.availableData
                                if data.isEmpty { break }
                                let remaining=max(0,8*1024*1024-stored)
                                if remaining>0 { let chunk=data.prefix(remaining);try? file.write(contentsOf:chunk);stored+=chunk.count }
                            }
                            readers.leave()
                        }
                    }
                    let deadline = Date().addingTimeInterval(timeout)
                    while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
                    let timedOut = process.isRunning
                    if timedOut {
                        let descendants=Self.descendants(of:process.processIdentifier)
                        descendants.forEach { kill($0,SIGTERM) }
                        process.terminate()
                        Thread.sleep(forTimeInterval: 0.15)
                        if process.isRunning { kill(process.processIdentifier, SIGKILL) };descendants.forEach { kill($0,SIGKILL) }
                    }
                    process.waitUntilExit()
                    // Children can retain stdout after their parent exits. Do not wait indefinitely.
                    _ = readers.wait(timeout: .now() + 1)
                    let out = (try? Data(contentsOf: outURL)) ?? Data(), err = (try? Data(contentsOf: errURL)) ?? Data()
                    continuation.resume(returning: CommandResult(stdout: String(decoding: out, as: UTF8.self), stderr: String(decoding: err, as: UTF8.self), exitCode: process.terminationStatus, timedOut: timedOut))
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
    private static func descendants(of parent:Int32)->[Int32] {
        let process=Process(),pipe=Pipe()
        process.executableURL=URL(fileURLWithPath:"/bin/ps");process.arguments=["-axo","pid=,ppid="]
        process.standardOutput=pipe;process.standardError=FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data=pipe.fileHandleForReading.readDataToEndOfFile();process.waitUntilExit()
        let pairs=String(decoding:data,as:UTF8.self).split(separator:"\n").compactMap { line -> (Int32,Int32)? in
            let values=line.split(whereSeparator:{$0.isWhitespace}).compactMap{Int32($0)}
            return values.count==2 ? (values[0],values[1]) : nil
        }
        var family:Set<Int32>=[parent],changed=true
        while changed { changed=false;for (pid,ppid) in pairs where family.contains(ppid) && !family.contains(pid) { family.insert(pid);changed=true } }
        return family.filter{$0 != parent}
    }
    public func checked(_ executable: String, _ arguments: [String], timeout: TimeInterval = 30) async throws -> String {
        let result = try await run(executable, arguments, timeout: timeout)
        guard result.succeeded else { throw CommandError.failed(result.timedOut ? "The command timed out. Try again after checking the tool." : String((result.stderr.isEmpty ? result.stdout : result.stderr).suffix(4000))) }
        return result.stdout
    }
    public static func locate(_ name: String) -> String? {
        guard !name.contains("/") else { return nil }
        for directory in (environment["PATH"] ?? "").split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        let local = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/" + name).path
        return FileManager.default.isExecutableFile(atPath: local) ? local : nil
    }
}
