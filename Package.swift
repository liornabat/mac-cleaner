// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "MacClean", platforms: [.macOS(.v14)], products: [.executable(name: "MacClean", targets: ["MacClean"]), .library(name: "MacCleanCore", targets: ["MacCleanCore"])], targets: [.target(name: "MacCleanCore"), .executableTarget(name: "MacClean", dependencies: ["MacCleanCore"],resources:[.copy("Resources/MacCleanIcon.png")]), .testTarget(name: "MacCleanCoreTests", dependencies: ["MacCleanCore"]), .testTarget(name:"MacCleanTests",dependencies:["MacClean","MacCleanCore"])], swiftLanguageModes: [.v5])
