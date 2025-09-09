// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SoundToLightTherapy",
    platforms: [
        .iOS(.v17),
        .macOS(.v12),
    ],
    products: [

        .library(
            name: "SoundToLightTherapy",
            targets: ["SoundToLightTherapy"]
        ),
        .executable(
            name: "SoundToLightTherapyApp",
            targets: ["SoundToLightTherapyApp"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/stackotter/swift-cross-ui",
            revision: "a02da752cf9cd50c99b3ce43d573975b69225d58")
    ],
    targets: [
        .target(
            name: "SoundToLightTherapy",
            dependencies: [
                .product(name: "SwiftCrossUI", package: "swift-cross-ui")
            ],
            path: "Sources/SoundToLightTherapy",
            exclude: ["main.swift"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "SoundToLightTherapyApp",
            dependencies: [
                .target(name: "SoundToLightTherapy"),
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "DefaultBackend", package: "swift-cross-ui"),
            ],
            path: "Sources/SoundToLightTherapy",
            sources: ["main.swift"]
        ),
        .testTarget(
            name: "SoundToLightTherapyTests",
            dependencies: ["SoundToLightTherapy"],
            path: "Tests/SoundToLightTherapyTests"
        ),
    ]
)
