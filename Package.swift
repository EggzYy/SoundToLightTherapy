// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SoundToLightTherapy",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "SoundToLightTherapyApp",
            targets: ["SoundToLightTherapyApp"]
        )
    ],
    dependencies: [
        // Pure SwiftUI implementation - no external dependencies
    ],
    targets: [
        .executableTarget(
            name: "SoundToLightTherapyApp",
            dependencies: [],
            path: "Sources",
            sources: [
                "SoundToLightTherapyApp/main.swift",
                "SoundToLightTherapy/Views/TherapyView.swift",
                "SoundToLightTherapy/Views/DynamicTypeTestView.swift",
                "SoundToLightTherapy/Managers/AudioCaptureManager.swift",
                "SoundToLightTherapy/Managers/FlashlightController.swift",
                "SoundToLightTherapy/Managers/FrequencyDetector.swift",
                "SoundToLightTherapy/Managers/TherapySessionCoordinator.swift",
                "SoundToLightTherapy/Utilities/DynamicTypeSupport.swift",
                "SoundToLightTherapy/Utilities/HapticFeedbackSupport.swift",
                "SoundToLightTherapy/Utilities/VoiceOverSupport.swift",
                "SoundToLightTherapy/Utilities/ColorContrastSupport.swift",
                "SoundToLightTherapy/Utilities/ReducedMotionSupport.swift",
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
