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
        // Removed SwiftCrossUI dependency to fix macro plugin issues
    ],
    targets: [
        .target(
            name: "SoundToLightTherapy",
            dependencies: [
                // Pure SwiftUI implementation - no external dependencies
            ],
            path: "Sources/SoundToLightTherapy",
            exclude: ["App.swift"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "SoundToLightTherapyApp",
            dependencies: [
                .target(name: "SoundToLightTherapy")
            ],
            path: "Sources/SoundToLightTherapyApp",
            sources: ["main.swift"]
        ),
        .testTarget(
            name: "SoundToLightTherapyTests",
            dependencies: ["SoundToLightTherapy"],
            path: "Tests/SoundToLightTherapyTests"
        ),
    ]
)
