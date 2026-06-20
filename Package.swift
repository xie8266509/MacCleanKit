// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacCleanKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacCleanKit", targets: ["MacCleanKit"])
    ],
    targets: [
        .executableTarget(
            name: "MacCleanKit",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
