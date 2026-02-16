// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacKeyManager",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "MacKeyManagerLib",
            path: "Sources/MacKeyManagerLib"
        ),
        .executableTarget(
            name: "MacKeyManager",
            dependencies: ["MacKeyManagerLib"],
            path: "Sources/MacKeyManager",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .executableTarget(
            name: "MacKeyManagerTests",
            dependencies: ["MacKeyManagerLib"],
            path: "Tests/MacKeyManagerTests",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
