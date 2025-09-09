import Foundation
import SwiftCrossUI

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(SwiftUI)
    import SwiftUI
#endif

// MARK: - Reduced Motion Support
/// Utility for handling reduced motion preferences on iOS.
/// This provides support for respecting user preferences regarding
/// motion and animations, following iOS accessibility guidelines.
public struct ReducedMotionSupport {

    // MARK: - Public API

    /// Checks if reduced motion is currently enabled based on iOS accessibility settings.
    @MainActor
    public static var isReducedMotionEnabled: Bool {
        #if canImport(UIKit)
            return UIAccessibility.isReduceMotionEnabled
        #else
            return false
        #endif
    }

    /// Returns a duration scale factor based on reduced motion settings.
    @MainActor
    public static func conditionalDuration(
        normal normalDuration: Double = 0.3,
        reduced reducedDuration: Double = 0.1
    ) -> Double {
        return isReducedMotionEnabled ? reducedDuration : normalDuration
    }

    /// Checks if animations should be used based on reduced motion settings.
    @MainActor
    public static var shouldUseAnimations: Bool {
        return !isReducedMotionEnabled
    }

    // MARK: - Therapy-Specific Durations

    /// Duration for frequency changes in the therapy app
    @MainActor
    public static var frequencyChangeDuration: Double {
        return conditionalDuration(normal: 0.3, reduced: 0.1)
    }

    /// Duration for session state changes
    @MainActor
    public static var sessionStateDuration: Double {
        return conditionalDuration(normal: 0.5, reduced: 0.2)
    }

    /// Duration for flashlight pulse effects
    @MainActor
    public static var flashlightPulseDuration: Double {
        return conditionalDuration(normal: 0.2, reduced: 0.1)
    }

    /// Provides conditional animation based on reduced motion preference
    @MainActor
    public static func conditionalAnimation() -> Any? {
        #if canImport(SwiftUI)
            return isReducedMotionEnabled ? nil : Animation.easeInOut(duration: 0.3)
        #else
            return nil
        #endif
    }

    /// Wraps content with conditional animation support
    @MainActor
    public static func withConditionalAnimation<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if canImport(SwiftUI)
            Group {
                if isReducedMotionEnabled {
                    content()
                } else {
                    content()
                        .animation(.easeInOut(duration: 0.3), value: UUID())
                }
            }
        #else
            content()
        #endif
    }

    /// Provides alternative static content when motion is reduced
    @MainActor
    public static func motionAlternative<AnimatedContent: View, StaticContent: View>(
        animated: @escaping () -> AnimatedContent,
        staticContent: @escaping () -> StaticContent
    ) -> some View {
        Group {
            if isReducedMotionEnabled {
                staticContent()
            } else {
                animated()
            }
        }
    }
}

// MARK: - View Extensions for Reduced Motion
extension View {
    /// Conditionally applies behavior based on reduced motion settings
    @MainActor
    public func respectsReducedMotion() -> some View {
        return self
    }

    /// Applies conditional animation that respects reduced motion preferences
    @MainActor
    public func conditionalAnimation<V: Equatable>(
        _ animation: Any?,
        value: V
    ) -> some View {
        #if canImport(SwiftUI)
            if ReducedMotionSupport.isReducedMotionEnabled {
                return AnyView(self)
            } else {
                return AnyView(self.animation(animation as? Animation, value: value))
            }
        #else
            return AnyView(self)
        #endif
    }

    /// Provides alternative presentations based on motion preference
    @MainActor
    public func motionSensitivePresentation<AlternativeContent: View>(
        @ViewBuilder alternative: @escaping () -> AlternativeContent
    ) -> some View {
        if ReducedMotionSupport.isReducedMotionEnabled {
            return AnyView(alternative())
        } else {
            return AnyView(self)
        }
    }
}
