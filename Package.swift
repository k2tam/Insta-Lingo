// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TransAtGlance",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "LookupCore", targets: ["LookupCore"]),
        .executable(name: "TransAtGlance", targets: ["TransAtGlance"]),
    ],
    targets: [
        .target(name: "LookupCore"),
        .executableTarget(name: "TransAtGlance", dependencies: ["LookupCore"]),
        .testTarget(name: "LookupCoreTests", dependencies: ["LookupCore"]),
    ]
)
