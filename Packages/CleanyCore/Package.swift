// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CleanyCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "CleanyCore", targets: ["CleanyCore"]),
    ],
    targets: [
        .target(name: "CleanyCore"),
        .testTarget(
            name: "CleanyCoreTests",
            dependencies: ["CleanyCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
