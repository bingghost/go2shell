// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Go2Term",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Go2Term", targets: ["Go2Term"]),
        .library(name: "Go2TermCore", targets: ["Go2TermCore"]),
    ],
    targets: [
        .target(name: "Go2TermCore"),
        .executableTarget(name: "Go2Term", dependencies: ["Go2TermCore"]),
        .testTarget(name: "Go2TermCoreTests", dependencies: ["Go2TermCore"]),
    ],
    swiftLanguageModes: [.v6]
)
