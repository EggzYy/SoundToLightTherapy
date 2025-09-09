import Foundation
import SwiftCrossUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Accessibility Traits Enum
/// Defines all accessibility traits for VoiceOver support
public struct AccessibilityTraits: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    // Standard accessibility traits
    public static let button = AccessibilityTraits(rawValue: 1 << 0)
    public static let header = AccessibilityTraits(rawValue: 1 << 1)
    public static let selected = AccessibilityTraits(rawValue: 1 << 2)
    public static let playsSound = AccessibilityTraits(rawValue: 1 << 3)
    public static let keyboardKey = AccessibilityTraits(rawValue: 1 << 4)
    public static let staticText = AccessibilityTraits(rawValue: 1 << 5)
    public static let summaryElement = AccessibilityTraits(rawValue: 1 << 6)
    public static let notEnabled = AccessibilityTraits(rawValue: 1 << 7)
    public static let updatesFrequently = AccessibilityTraits(rawValue: 1 << 8)
    public static let searchField = AccessibilityTraits(rawValue: 1 << 9)
    public static let startsMediaSession = AccessibilityTraits(rawValue: 1 << 10)
    public static let adjustable = AccessibilityTraits(rawValue: 1 << 11)
    public static let allowsDirectInteraction = AccessibilityTraits(rawValue: 1 << 12)
    public static let causesPageTurn = AccessibilityTraits(rawValue: 1 << 13)
    public static let tabBar = AccessibilityTraits(rawValue: 1 << 14)

    // Custom traits for therapy app
    public static let therapyControl = AccessibilityTraits(rawValue: 1 << 15)
    public static let frequencyAdjuster = AccessibilityTraits(rawValue: 1 << 16)
    public static let sessionStatus = AccessibilityTraits(rawValue: 1 << 17)
}

// MARK: - Accessibility Announcer
/// Utility for making accessibility announcements
public actor AccessibilityAnnouncer {
    public static let shared = AccessibilityAnnouncer()

    private init() {}

    @MainActor
    public func announce(_ message: String) {
        #if canImport(UIKit)
            UIAccessibility.post(notification: .announcement, argument: message)
        #else
            print("Accessibility announcement: \(message)")
        #endif
    }

    public func announceSessionStarted() async {
        await announce("Therapy session started")
    }

    public func announceSessionStopped() async {
        await announce("Therapy session stopped")
    }

    public func announceFrequencyChange(_ frequency: Float) async {
        await announce("Frequency changed to \(String(format: "%.1f", frequency)) Hertz")
    }

    public func announceFlashlightState(_ isOn: Bool) async {
        let state = isOn ? "on" : "off"
        await announce("Flashlight turned \(state)")
    }

    public func announceEmergencyStop() async {
        await announce("Emergency stop activated. Therapy session terminated immediately.")
    }

    public func announceSessionProgress(_ progress: Double) async {
        let percentage = Int(progress * 100)
        await announce("Session progress: \(percentage) percent complete")
    }
}

// MARK: - VoiceOver Configuration Support
/// Utility methods for configuring VoiceOver accessibility
public struct VoiceOverSupport {

    /// Configures accessibility properties for a view
    /// - Note: SwiftCrossUI compatible - accessibility methods removed due to unsupported APIs
    /// TODO: Implement accessibility support when SwiftCrossUI adds accessibility APIs
    @MainActor
    public static func configureAccessibility<V: SwiftUI.View>(
        for view: V,
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some SwiftUI.View {
        // SwiftCrossUI doesn't support accessibility modifiers yet
        // Return the view as-is for now
        return view
    }

    /// Validates that all interactive elements have proper accessibility labels
    @MainActor
    public static func validateAccessibilityElements() -> [String] {
        var issues: [String] = []

        // This would typically inspect the view hierarchy, but for now we'll return
        // validation guidelines that should be manually checked
        issues.append("Ensure all buttons have descriptive accessibility labels")
        issues.append("Verify sliders have proper value announcements")
        issues.append("Check that progress indicators announce updates")
        issues.append("Confirm emergency controls are clearly labeled")

        return issues
    }

    /// Checks if VoiceOver is currently running
    @MainActor
    public static var isVoiceOverRunning: Bool {
        #if canImport(UIKit)
            return UIAccessibility.isVoiceOverRunning
        #else
            return false
        #endif
    }
}

// MARK: - VoiceOver Rotor Support
/// VoiceOver rotor for navigating through therapy app elements
public struct VoiceOverRotor {
    public enum RotorType {
        case therapyControls
        case frequencyAdjusters
        case sessionStatus
        case navigation
        case emergencyControls
        case custom(String)

        var accessibilityLabel: String {
            switch self {
            case .therapyControls: return "Therapy Controls"
            case .frequencyAdjusters: return "Frequency Adjusters"
            case .sessionStatus: return "Session Status"
            case .navigation: return "Navigation"
            case .emergencyControls: return "Emergency Controls"
            case .custom(let label): return label
            }
        }

        var identifier: String {
            switch self {
            case .therapyControls: return "therapy_controls"
            case .frequencyAdjusters: return "frequency_adjusters"
            case .sessionStatus: return "session_status"
            case .navigation: return "navigation"
            case .emergencyControls: return "emergency_controls"
            case .custom(let id): return id
            }
        }
    }
}
