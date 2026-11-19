// swift-tools-version: 5.9
// Flipping Dice (Classic) & FD_too0 — Gravity Wizards, Inc. / akapps Heritage
// Opens directly in Xcode 15/16+ on macOS (File -> Open Package.swift) and builds for iOS, iPadOS & macOS.

import PackageDescription

let package = Package(
    name: "FD_too0",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "FDToo0App",
            targets: ["FDToo0App"]
        ),
        .library(
            name: "FDToo0Core",
            targets: ["FDToo0Core"]
        )
    ],
    targets: [
        .target(
            name: "FDToo0Core",
            path: "Sources/FDToo0Core"
        ),
        .executableTarget(
            name: "FDToo0App",
            dependencies: ["FDToo0Core"],
            path: "Sources/FDToo0App",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "FDToo0CoreTests",
            dependencies: ["FDToo0Core"],
            path: "Tests/FDToo0CoreTests"
        )
    ]
)
