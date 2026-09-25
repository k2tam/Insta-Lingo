// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "InstaLingo",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "LookupCore", targets: ["LookupCore"]),
        .executable(name: "InstaLingo", targets: ["InstaLingo"]),
    ],
    targets: [
        .target(name: "LookupCore"),
        .executableTarget(name: "InstaLingo", dependencies: ["LookupCore"]),
        .testTarget(name: "LookupCoreTests", dependencies: ["LookupCore"]),
    ]
)
