import Foundation
import SwiftCrossUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Platform-agnostic Haptic Feedback Types

/// Types of haptic feedback patterns available
public enum HapticFeedbackType {
    case success
    case warning
    case error
    case lightImpact
    case mediumImpact
    case heavyImpact
    case selection
    case notification(type: NotificationType)
}

/// Platform-agnostic notification types for haptic feedback
public enum NotificationType {
    case success
    case warning
    case error
}

/// Platform-agnostic impact styles for haptic feedback
public enum ImpactStyle {
    case light
    case medium
    case heavy
    case soft
    case rigid
}

// MARK: - Haptic Feedback Support

/// Utility for generating haptic feedback on iOS with accessibility support
public enum HapticFeedbackSupport {

    // MARK: - Core Haptic Generation

    /// Generates haptic feedback based on the specified type.
    ///
    /// - Parameters:
    ///   - type: The type of haptic feedback to generate
    ///   - respectReducedMotion: Whether to respect reduced motion settings
    /// - Returns: `true` if feedback was successfully generated
    @MainActor
    public static func generate(_ type: HapticFeedbackType, respectReducedMotion: Bool = true)
        -> Bool
    {
        return generateCommonHaptic(type, respectReducedMotion: respectReducedMotion)
    }

    /// Generates selection haptic feedback.
    ///
    /// - Parameters:
    ///   - respectReducedMotion: Whether to respect reduced motion settings
    /// - Returns: `true` if feedback was successfully generated
    @MainActor
    public static func generateSelection(respectReducedMotion: Bool = true) -> Bool {
        if respectReducedMotion && ReducedMotionSupport.isReducedMotionEnabled {
            return generateReducedMotionAlternative(forSelection: ())
        }

        return generateNativeSelection()
    }

    // MARK: - Platform-specific implementations

    /// Generates impact haptic feedback with customizable intensity.
    ///
    /// - Parameters:
    ///   - style: The impact style (light, medium, heavy)
    ///   - intensity: Custom intensity from 0.0 to 1.0
    ///   - respectReducedMotion: Whether to respect reduced motion settings
    /// - Returns: `true` if feedback was successfully generated
    @MainActor
    public static func generateImpact(
        style: ImpactStyle,
        intensity: CGFloat = 1.0,
        respectReducedMotion: Bool = true
    ) -> Bool {
        #if canImport(UIKit)
            let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
            switch style {
            case .light: uiStyle = .light
            case .medium: uiStyle = .medium
            case .heavy: uiStyle = .heavy
            case .soft: uiStyle = .soft
            case .rigid: uiStyle = .rigid
            }
            if respectReducedMotion && ReducedMotionSupport.isReducedMotionEnabled {
                return generateReducedMotionAlternative(forImpactStyle: uiStyle)
            }

            return generateNativeImpact(style: uiStyle, intensity: intensity)
        #else
            return false  // No haptic feedback on non-iOS platforms
        #endif
    }

    /// Generates notification haptic feedback.
    ///
    /// - Parameters:
    ///   - notificationType: The notification type (success, warning, error)
    ///   - respectReducedMotion: Whether to respect reduced motion settings
    /// - Returns: `true` if feedback was successfully generated
    @MainActor
    public static func generateNotification(
        _ notificationType: NotificationType,
        respectReducedMotion: Bool = true
    ) -> Bool {
        #if canImport(UIKit)
            let uiType: UINotificationFeedbackGenerator.FeedbackType
            switch notificationType {
            case .success: uiType = .success
            case .warning: uiType = .warning
            case .error: uiType = .error
            }
            if respectReducedMotion && ReducedMotionSupport.isReducedMotionEnabled {
                return generateReducedMotionAlternative(forNotificationType: uiType)
            }

            return generateNativeNotification(uiType)
        #else
            return false  // No haptic feedback on non-iOS platforms
        #endif
    }

    // MARK: - Common Haptic Generation

    @MainActor
    private static func generateCommonHaptic(
        _ type: HapticFeedbackType, respectReducedMotion: Bool = true
    ) -> Bool {
        switch type {
        case .success:
            return generateNotification(.success, respectReducedMotion: respectReducedMotion)
        case .warning:
            return generateNotification(.warning, respectReducedMotion: respectReducedMotion)
        case .error:
            return generateNotification(.error, respectReducedMotion: respectReducedMotion)
        case .lightImpact:
            return generateImpact(style: .light, respectReducedMotion: respectReducedMotion)
        case .mediumImpact:
            return generateImpact(style: .medium, respectReducedMotion: respectReducedMotion)
        case .heavyImpact:
            return generateImpact(style: .heavy, respectReducedMotion: respectReducedMotion)
        case .selection:
            return generateSelection(respectReducedMotion: respectReducedMotion)
        case .notification(let type):
            return generateNotification(type, respectReducedMotion: respectReducedMotion)
        }
    }
}

// MARK: - Platform-specific Implementations

// Haptic feedback implementation
extension HapticFeedbackSupport {

    #if canImport(UIKit)
        // Shared generators for better performance
        @MainActor private static let impactGeneratorLight = UIImpactFeedbackGenerator(
            style: .light)
        @MainActor private static let impactGeneratorMedium = UIImpactFeedbackGenerator(
            style: .medium)
        @MainActor private static let impactGeneratorHeavy = UIImpactFeedbackGenerator(
            style: .heavy)
        @MainActor private static let notificationGenerator = UINotificationFeedbackGenerator()
        @MainActor private static let selectionGenerator = UISelectionFeedbackGenerator()

        @MainActor
        private static func generateNativeImpact(
            style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1.0
        ) -> Bool {
            let generator: UIImpactFeedbackGenerator
            switch style {
            case .light:
                generator = impactGeneratorLight
            case .medium:
                generator = impactGeneratorMedium
            case .heavy:
                generator = impactGeneratorHeavy
            case .soft:
                generator = UIImpactFeedbackGenerator(style: .soft)
            case .rigid:
                generator = UIImpactFeedbackGenerator(style: .rigid)
            @unknown default:
                generator = impactGeneratorMedium
            }

            generator.prepare()
            generator.impactOccurred(intensity: intensity)
            return true
        }

        @MainActor
        private static func generateNativeNotification(
            _ type: UINotificationFeedbackGenerator.FeedbackType
        ) -> Bool {
            notificationGenerator.prepare()
            notificationGenerator.notificationOccurred(type)
            return true
        }

        @MainActor
        private static func generateNativeSelection() -> Bool {
            selectionGenerator.prepare()
            selectionGenerator.selectionChanged()
            return true
        }

        @MainActor
        private static func generateReducedMotionAlternative(
            forImpactStyle style: UIImpactFeedbackGenerator.FeedbackStyle
        ) -> Bool {
            return generateNativeImpact(style: .light, intensity: 0.3)
        }

        @MainActor
        private static func generateReducedMotionAlternative(
            forNotificationType type: UINotificationFeedbackGenerator.FeedbackType
        ) -> Bool {
            return generateNativeImpact(style: .light, intensity: 0.3)
        }

        @MainActor
        private static func generateReducedMotionAlternative(forSelection: ()) -> Bool {
            return generateNativeImpact(style: .light, intensity: 0.2)
        }
    #else
        // Stub implementations for non-iOS platforms
        @MainActor
        private static func generateNativeImpact(style: Any, intensity: CGFloat = 1.0) -> Bool {
            return false
        }

        @MainActor
        private static func generateNativeNotification(_ type: Any) -> Bool {
            return false
        }

        @MainActor
        private static func generateNativeSelection() -> Bool {
            return false
        }

        @MainActor
        private static func generateReducedMotionAlternative(forImpactStyle style: Any) -> Bool {
            return false
        }

        @MainActor
        private static func generateReducedMotionAlternative(forNotificationType type: Any) -> Bool
        {
            return false
        }

        @MainActor
        private static func generateReducedMotionAlternative(forSelection: ()) -> Bool {
            return false
        }
    #endif
}

// MARK: - SwiftCrossUI View Extensions
extension View {
    /// Applies haptic feedback to a view interaction.
    ///
    /// - Parameters:
    ///   - type: The type of haptic feedback to generate
    ///   - respectReducedMotion: Whether to respect reduced motion settings
    /// - Returns: A view that generates haptic feedback on interaction
    /// - Note: SwiftCrossUI compatible - removed due to unsupported onTapGesture behavior
    /// TODO: Implement haptic feedback for SwiftCrossUI when gesture support is added
    public func withHapticFeedback(_ type: HapticFeedbackType, respectReducedMotion: Bool = true)
        -> some SwiftUI.View
    {
        // SwiftCrossUI doesn't support the onTapGesture modifier in the same way
        // Return self for now - haptic feedback will be handled manually in button actions
        return self
    }
}
