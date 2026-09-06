// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MaeumjaroCore",
    defaultLocalization: "ko",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MaeumjaroDomain", targets: ["MaeumjaroDomain"]),
        .library(name: "MaeumjaroShared", targets: ["MaeumjaroShared"]),
        .library(name: "MaeumjaroPersistence", targets: ["MaeumjaroPersistence"]),
        .library(name: "MaeumjaroIntents", targets: ["MaeumjaroIntents"]),
        .executable(name: "MaeumjaroCoreProbe", targets: ["MaeumjaroCoreProbe"])
    ],
    targets: [
        .target(
            name: "MaeumjaroDomain",
            resources: [.process("Resources")]
        ),
        .target(
            name: "MaeumjaroShared",
            dependencies: ["MaeumjaroDomain"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "MaeumjaroPersistence",
            dependencies: ["MaeumjaroDomain", "MaeumjaroShared"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "MaeumjaroIntents",
            dependencies: ["MaeumjaroDomain", "MaeumjaroShared"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "MaeumjaroCoreProbe",
            dependencies: [
                "MaeumjaroDomain",
                "MaeumjaroShared",
                "MaeumjaroPersistence",
                "MaeumjaroIntents"
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MaeumjaroDomainTests", dependencies: ["MaeumjaroDomain"]),
        .testTarget(name: "MaeumjaroSharedTests", dependencies: ["MaeumjaroShared"]),
        .testTarget(name: "MaeumjaroPersistenceTests", dependencies: ["MaeumjaroPersistence"]),
        .testTarget(name: "MaeumjaroIntentsTests", dependencies: ["MaeumjaroIntents"])
    ]
)
