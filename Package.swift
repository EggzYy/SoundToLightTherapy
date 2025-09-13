// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SoundToLightTherapy",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Xtool project requires exactly one library product representing the main app
        .library(
            name: "SoundToLightTherapy",
            targets: ["SoundToLightTherapy"]
        )
    ],
    dependencies: [
        // Pure SwiftUI implementation - no external dependencies
    ],
    targets: [
        .target(
            name: "SoundToLightTherapy",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
