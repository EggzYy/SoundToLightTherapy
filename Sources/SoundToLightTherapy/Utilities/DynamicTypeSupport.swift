import Foundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Content Size Category Enum

/// Comprehensive enumeration of all content size categories for iOS Dynamic Type support.
/// This enum provides a unified interface for handling text scaling on iOS,
/// ensuring accessibility compliance with WCAG 2.1 and iOS Human Interface Guidelines.
///
/// The categories range from extraSmall to accessibilityExtraExtraExtraLarge, covering all
/// standard and accessibility-specific content size preferences.
///
/// - Important: This maps directly to `UIContentSizeCategory` for iOS-specific implementation.
///
/// - SeeAlso: `UIContentSizeCategory` (iOS)
public enum ContentSizeCategory: String, CaseIterable, Sendable {
    case extraSmall
    case small
    case medium
    case large
    case extraLarge
    case extraExtraLarge
    case extraExtraExtraLarge
    case accessibilityMedium
    case accessibilityLarge
    case accessibilityExtraLarge
    case accessibilityExtraExtraLarge
    case accessibilityExtraExtraExtraLarge

    /// Converts the content size category to a UIContentSizeCategory representation.
    ///
    /// - Returns: `UIContentSizeCategory` instance
    #if canImport(UIKit)
        public func toPlatformSizeCategory() -> UIContentSizeCategory {
            return toUIContentSizeCategory()
        }
    #else
        public func toPlatformSizeCategory() -> String {
            return self.rawValue
        }
    #endif

    /// Converts to iOS-specific `UIContentSizeCategory`.
    ///
    /// This method provides the direct mapping between the enum
    /// and Apple's native content size category system.
    ///
    /// - Returns: Corresponding `UIContentSizeCategory` value
    #if canImport(UIKit)
        internal func toUIContentSizeCategory() -> UIContentSizeCategory {
            switch self {
            case .extraSmall: return .extraSmall
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .extraLarge: return .extraLarge
            case .extraExtraLarge: return .extraExtraLarge
            case .extraExtraExtraLarge: return .extraExtraExtraLarge
            case .accessibilityMedium: return .accessibilityMedium
            case .accessibilityLarge: return .accessibilityLarge
            case .accessibilityExtraLarge: return .accessibilityExtraLarge
            case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
            case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
            }
        }
    #else
        internal func toUIContentSizeCategory() -> String {
            return self.rawValue
        }
    #endif

    /// Retrieves the current content size category from the system.
    ///
    /// This uses platform-specific APIs to get the current content size category.
    ///
    /// - Returns: The current content size category based on system settings
    /// - Note: Returns .medium as fallback on non-iOS platforms or when unavailable.
    @MainActor
    public static func current() -> ContentSizeCategory {
        #if canImport(UIKit)
            let currentCategory = UIApplication.shared.preferredContentSizeCategory
            return fromUIContentSizeCategory(currentCategory)
        #else
            return .medium
        #endif
    }

    /// Converts from iOS `UIContentSizeCategory` to the enum.
    ///
    /// This method handles the reverse mapping from Apple's native content size
    /// categories to our unified representation.
    ///
    /// - Parameter category: The iOS content size category to convert
    /// - Returns: Corresponding `ContentSizeCategory` value
    /// - Note: Returns `.medium` as fallback for unknown categories
    #if canImport(UIKit)
        private static func fromUIContentSizeCategory(_ category: UIContentSizeCategory)
            -> ContentSizeCategory
        {
            switch category {
            case .extraSmall: return .extraSmall
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .extraLarge: return .extraLarge
            case .extraExtraLarge: return .extraExtraLarge
            case .extraExtraExtraLarge: return .extraExtraExtraLarge
            case .accessibilityMedium: return .accessibilityMedium
            case .accessibilityLarge: return .accessibilityLarge
            case .accessibilityExtraLarge: return .accessibilityExtraLarge
            case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
            case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
            default: return .medium
            }
        }
    #else
        private static func fromUIContentSizeCategory(_ category: String) -> ContentSizeCategory {
            return ContentSizeCategory(rawValue: category) ?? .medium
        }
    #endif
}

// MARK: - Text Style Enum

/// Comprehensive enumeration of all standard text styles for scalable font support.
/// This enum defines the base sizes and weights for each text style, following
/// iOS typography guidelines.
///
/// Each text style has a base size (for medium content size category) and a
/// recommended font weight, ensuring consistent visual hierarchy across the app.
///
/// - Important: Base sizes are defined in points and are scaled dynamically
///   based on the content size category. Weights are applied consistently
///   to maintain visual design principles.
///
/// - SeeAlso: `ContentSizeCategory`, `DynamicTypeSupport.font(for:)`
public enum TextStyle: String, CaseIterable, Sendable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case callout
    case footnote
    case caption
    case caption2

    /// The base font size for each text style in points, corresponding to the medium content size category.
    ///
    /// These sizes are based on iOS typography guidelines and provide a consistent
    /// starting point for dynamic scaling across all content size categories.
    ///
    /// - Returns: Base font size in points as `Double`
    /// - Note: These sizes are scaled up or down based on the content size category
    ///   using UIFontMetrics.
    public var baseSize: Double {
        switch self {
        case .largeTitle: return 34.0
        case .title: return 28.0
        case .title2: return 22.0
        case .title3: return 20.0
        case .headline: return 17.0
        case .subheadline: return 15.0
        case .body: return 17.0
        case .callout: return 16.0
        case .footnote: return 13.0
        case .caption: return 12.0
        case .caption2: return 11.0
        }
    }
}

// MARK: - Dynamic Type Support

/// Main utility struct providing iOS Dynamic Type support for scalable fonts.
/// This struct handles the iOS-specific implementation details using UIFontMetrics.
///
/// - Important: For SwiftCrossUI compatibility, this provides simplified font creation
///   without UIFontMetrics scaling.
///
/// - SeeAlso: `ContentSizeCategory`, `TextStyle`, `View.scalableFont(_:)`
public struct DynamicTypeSupport {
    /// Creates a font based on the text style for SwiftCrossUI compatibility
    ///
    /// This provides a simple font creation method that works with SwiftCrossUI
    /// without requiring ViewModifier support.
    ///
    /// - Parameter textStyle: The text style to create a font for
    /// - Returns: A Font instance sized appropriately for the text style
    public static func font(for textStyle: TextStyle) -> Font {
        return .system(size: textStyle.baseSize)
    }

    /// Checks if text with the given style is readable at the current content size category
    ///
    /// This method helps determine if text meets accessibility guidelines for readability
    /// by checking if the scaled font size is above minimum readable thresholds.
    ///
    /// - Parameter textStyle: The text style to check
    /// - Returns: Boolean indicating if text is readable
    @MainActor
    public static func isTextReadable(for textStyle: TextStyle) -> Bool {
        let currentCategory = ContentSizeCategory.current()
        let scaledSize = getScaledSize(for: textStyle, category: currentCategory)

        // Minimum readable sizes based on WCAG guidelines
        let minimumReadableSize: Double = {
            switch textStyle {
            case .largeTitle, .title, .title2, .title3, .headline:
                return 18.0  // Larger text should be at least 18pt
            case .body, .callout:
                return 16.0  // Body text should be at least 16pt
            case .subheadline, .footnote:
                return 14.0  // Smaller supporting text should be at least 14pt
            case .caption, .caption2:
                return 12.0  // Caption text should be at least 12pt
            }
        }()

        return scaledSize >= minimumReadableSize
    }

    /// Gets the scaled size for a text style at the given content size category
    private static func getScaledSize(for textStyle: TextStyle, category: ContentSizeCategory)
        -> Double
    {
        let baseSize = textStyle.baseSize

        // Scaling factors based on content size category
        let scalingFactor: Double = {
            switch category {
            case .extraSmall: return 0.8
            case .small: return 0.9
            case .medium: return 1.0
            case .large: return 1.1
            case .extraLarge: return 1.2
            case .extraExtraLarge: return 1.3
            case .extraExtraExtraLarge: return 1.4
            case .accessibilityMedium: return 1.5
            case .accessibilityLarge: return 1.8
            case .accessibilityExtraLarge: return 2.2
            case .accessibilityExtraExtraLarge: return 2.7
            case .accessibilityExtraExtraExtraLarge: return 3.2
            }
        }()

        return baseSize * scalingFactor
    }
}

// MARK: - View Extensions (SwiftCrossUI Compatible)
extension View {
    /// Applies a scalable font with the given text style to the view.
    ///
    /// This is the primary method for enabling Dynamic Type support in views.
    /// It replaces the need for hardcoded font sizes and ensures text scales
    /// appropriately based on user accessibility settings.
    ///
    /// - Parameter textStyle: The text style to apply (e.g., .title, .body, .caption)
    /// - Returns: A modified view with scalable font applied
    /// - Note: SwiftCrossUI compatible - uses basic font sizing without dynamic scaling
    public func scalableFont(_ textStyle: TextStyle) -> some SwiftUI.View {
        return self.font(DynamicTypeSupport.font(for: textStyle))
    }

    /// Configures the view to adapt to content size category changes automatically.
    ///
    /// This method sets up the environment to observe content size category changes
    /// and re-render the view accordingly.
    ///
    /// - Returns: A view configured to respond to content size category changes
    /// - Note: SwiftCrossUI compatible - returns self as no dynamic scaling is available
    public func adaptsToContentSizeCategory() -> some SwiftUI.View {
        // SwiftCrossUI doesn't support dynamic type scaling, so return self
        return self
    }
}
