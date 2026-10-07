// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MacClean", platforms: [.macOS(.v14)], products: [.executable(name: "MacClean", targets: ["MacClean"]), .library(name: "MacCleanCore", targets: ["MacCleanCore"])], targets: [.target(name: "MacCleanCore"), .executableTarget(name: "MacClean", dependencies: ["MacCleanCore"]), .testTarget(name: "MacCleanCoreTests", dependencies: ["MacCleanCore"])], swiftLanguageModes: [.v5])
