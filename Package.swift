// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Go2Shell",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Go2Shell", targets: ["Go2Shell"]),
        .library(name: "Go2ShellCore", targets: ["Go2ShellCore"]),
    ],
    targets: [
        .target(name: "Go2ShellCore"),
        .executableTarget(name: "Go2Shell", dependencies: ["Go2ShellCore"]),
        .testTarget(name: "Go2ShellCoreTests", dependencies: ["Go2ShellCore"]),
    ],
    swiftLanguageModes: [.v6]
)
