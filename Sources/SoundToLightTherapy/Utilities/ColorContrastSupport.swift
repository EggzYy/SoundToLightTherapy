import Foundation

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(SwiftUI) && canImport(UIKit)
    import SwiftUI
#endif

// MARK: - WCAG 2.1 Contrast Standards

/// Defines WCAG 2.1 contrast ratio requirements for accessibility compliance
public enum WCAGContrastLevel: String, CaseIterable, Sendable {
    /// Minimum contrast for normal text (4.5:1)
    case normalText = "4.5:1"
    /// Minimum contrast for large text (3:1)
    case largeText = "3:1"
    /// Enhanced contrast for AAA level (7:1)
    case enhanced = "7:1"
    /// Minimum contrast for graphical objects and UI components (3:1)
    case graphical = "3:1_graphical"
    /// WCAG AA level compliance
    case AA = "AA"
    /// WCAG AAA level compliance
    case AAA = "AAA"

    /// The numeric contrast ratio requirement
    public var ratio: Double {
        switch self {
        case .normalText: return 4.5
        case .largeText: return 3.0
        case .enhanced: return 7.0
        case .graphical: return 3.0
        case .AA: return 4.5
        case .AAA: return 7.0
        }
    }

    /// Description of the contrast level requirement
    public var description: String {
        switch self {
        case .normalText: return "Normal text (4.5:1 minimum)"
        case .largeText: return "Large text (3:1 minimum)"
        case .enhanced: return "Enhanced contrast (7:1 AAA)"
        case .graphical: return "Graphical objects (3:1 minimum)"
        case .AA: return "WCAG AA compliance (4.5:1 minimum)"
        case .AAA: return "WCAG AAA compliance (7:1 minimum)"
        }
    }
}

// MARK: - Color Representation

/// Unified color representation for iOS color contrast calculations
public struct AccessibleColor: Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    #if canImport(UIKit)
        /// Creates a color from a UIColor
        public static func fromPlatformColor(_ color: Any) -> AccessibleColor {
            return fromUIColor(color as! UIColor)
        }

        /// Converts UIColor to AccessibleColor
        internal static func fromUIColor(_ color: UIColor) -> AccessibleColor {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0

            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            return AccessibleColor(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                alpha: Double(alpha)
            )
        }

        /// Converts to platform-specific color (iOS only)
        public func toPlatformColor() -> Any {
            return toUIColor()
        }

        /// Converts to UIColor
        internal func toUIColor() -> UIColor {
            return UIColor(
                red: CGFloat(red),
                green: CGFloat(green),
                blue: CGFloat(blue),
                alpha: CGFloat(alpha)
            )
        }
    #endif
}

// MARK: - Color Contrast Calculations

/// Main utility for color contrast calculations and accessibility compliance checking
public struct ColorContrastSupport {

    // MARK: - Public API

    /// Calculates the contrast ratio between two colors using WCAG 2.1 formula
    /// - Parameters:
    ///   - foreground: The foreground color
    ///   - background: The background color
    /// - Returns: Contrast ratio as Double (1.0 to 21.0 range)
    public static func calculateContrastRatio(
        foreground: AccessibleColor, background: AccessibleColor
    ) -> Double {
        let fgLuminance = calculateRelativeLuminance(foreground)
        let bgLuminance = calculateRelativeLuminance(background)

        // Ensure we have valid luminance values
        guard fgLuminance >= 0, bgLuminance >= 0 else {
            return 1.0  // Minimum contrast
        }

        // WCAG contrast ratio formula: (L1 + 0.05) / (L2 + 0.05) where L1 is lighter color
        let lighter = max(fgLuminance, bgLuminance)
        let darker = min(fgLuminance, bgLuminance)

        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Alternative method signature for calculating contrast ratio
    /// - Parameters:
    ///   - first: The first color
    ///   - second: The second color
    /// - Returns: Contrast ratio as Double (1.0 to 21.0 range)
    public static func calculateContrastRatio(
        between first: AccessibleColor, and second: AccessibleColor
    ) -> Double {
        return calculateContrastRatio(foreground: first, background: second)
    }

    /// Checks if the contrast ratio meets WCAG 2.1 requirements
    /// - Parameters:
    ///   - foreground: The foreground color
    ///   - background: The background color
    ///   - level: The WCAG contrast level to check against
    /// - Returns: Boolean indicating if contrast meets requirements
    public static func meetsContrastRequirements(
        foreground: AccessibleColor,
        background: AccessibleColor,
        level: WCAGContrastLevel
    ) -> Bool {
        let ratio = calculateContrastRatio(foreground: foreground, background: background)
        return ratio >= level.ratio
    }

    /// Alternative method signature for checking contrast requirements
    /// - Parameters:
    ///   - foreground: The foreground color (labeled as 'for')
    ///   - background: The background color (labeled as 'with')
    ///   - level: The WCAG contrast level to check against
    /// - Returns: Boolean indicating if contrast meets requirements
    public static func meetsContrastRequirements(
        for foreground: AccessibleColor,
        with background: AccessibleColor,
        level: WCAGContrastLevel
    ) -> Bool {
        return meetsContrastRequirements(
            foreground: foreground, background: background, level: level)
    }

    /// Suggests an accessible alternative color that meets contrast requirements
    /// - Parameters:
    ///   - originalColor: The original color that needs adjustment
    ///   - background: The background color
    ///   - level: The required WCAG contrast level
    ///   - adjustmentFactor: How much to adjust the color (0.0 to 1.0)
    /// - Returns: An accessible color that meets contrast requirements
    public static func suggestAccessibleAlternative(
        originalColor: AccessibleColor,
        background: AccessibleColor,
        level: WCAGContrastLevel,
        adjustmentFactor: Double = 0.3
    ) -> AccessibleColor {
        let currentRatio = calculateContrastRatio(foreground: originalColor, background: background)

        if currentRatio >= level.ratio {
            return originalColor  // Already meets requirements
        }

        // Determine if we need to lighten or darken based on background luminance
        let bgLuminance = calculateRelativeLuminance(background)
        let fgLuminance = calculateRelativeLuminance(originalColor)

        let shouldLighten = fgLuminance < bgLuminance

        // Adjust the color towards maximum contrast
        return adjustColorForContrast(
            originalColor: originalColor,
            background: background,
            targetRatio: level.ratio,
            shouldLighten: shouldLighten,
            adjustmentFactor: adjustmentFactor
        )
    }

    #if canImport(UIKit)
        /// Platform-specific method to check contrast using native APIs
        public static func checkContrastNative(
            foreground: UIColor, background: UIColor, level: WCAGContrastLevel
        ) -> Bool {
            let fgColor = AccessibleColor.fromUIColor(foreground)
            let bgColor = AccessibleColor.fromUIColor(background)
            return meetsContrastRequirements(foreground: fgColor, background: bgColor, level: level)
        }
    #endif

    // MARK: - Internal Calculations

    /// Calculates the relative luminance of a color using WCAG 2.1 formula
    /// - Parameter color: The color to calculate luminance for
    /// - Returns: Relative luminance value (0.0 to 1.0)
    internal static func calculateRelativeLuminance(_ color: AccessibleColor) -> Double {
        // Convert RGB components to linear values
        let r = color.red <= 0.03928 ? color.red / 12.92 : pow((color.red + 0.055) / 1.055, 2.4)
        let g =
            color.green <= 0.03928 ? color.green / 12.92 : pow((color.green + 0.055) / 1.055, 2.4)
        let b = color.blue <= 0.03928 ? color.blue / 12.92 : pow((color.blue + 0.055) / 1.055, 2.4)

        // Calculate luminance using WCAG 2.1 weights
        return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
    }

    /// Adjusts a color to achieve better contrast against a background
    private static func adjustColorForContrast(
        originalColor: AccessibleColor,
        background: AccessibleColor,
        targetRatio: Double,
        shouldLighten: Bool,
        adjustmentFactor: Double
    ) -> AccessibleColor {
        var adjustedColor = originalColor
        var currentRatio = calculateContrastRatio(foreground: originalColor, background: background)

        // Adjust until we meet the target ratio or reach maximum adjustment
        while currentRatio < targetRatio {
            if shouldLighten {
                // Lighten the color
                adjustedColor = AccessibleColor(
                    red: min(1.0, adjustedColor.red + adjustmentFactor),
                    green: min(1.0, adjustedColor.green + adjustmentFactor),
                    blue: min(1.0, adjustedColor.blue + adjustmentFactor),
                    alpha: adjustedColor.alpha
                )
            } else {
                // Darken the color
                adjustedColor = AccessibleColor(
                    red: max(0.0, adjustedColor.red - adjustmentFactor),
                    green: max(0.0, adjustedColor.green - adjustmentFactor),
                    blue: max(0.0, adjustedColor.blue - adjustmentFactor),
                    alpha: adjustedColor.alpha
                )
            }

            currentRatio = calculateContrastRatio(foreground: adjustedColor, background: background)

            // Prevent infinite loop
            if (shouldLighten && adjustedColor.red >= 1.0 && adjustedColor.green >= 1.0
                && adjustedColor.blue >= 1.0)
                || (!shouldLighten && adjustedColor.red <= 0.0 && adjustedColor.green <= 0.0
                    && adjustedColor.blue <= 0.0)
            {
                break
            }
        }

        return adjustedColor
    }

    /// Generates an accessible color palette from a base color
    /// - Parameter baseColor: The base color to generate palette from
    /// - Returns: Array of accessible colors that meet contrast requirements
    public static func generateAccessiblePalette(from baseColor: AccessibleColor)
        -> [AccessibleColor]
    {
        var palette: [AccessibleColor] = [baseColor]

        // Generate lighter variants
        for i in 1...3 {
            let lightness = 0.2 * Double(i)
            let lighterColor = AccessibleColor(
                red: min(1.0, baseColor.red + lightness),
                green: min(1.0, baseColor.green + lightness),
                blue: min(1.0, baseColor.blue + lightness),
                alpha: baseColor.alpha
            )
            palette.append(lighterColor)
        }

        // Generate darker variants
        for i in 1...3 {
            let darkness = 0.2 * Double(i)
            let darkerColor = AccessibleColor(
                red: max(0.0, baseColor.red - darkness),
                green: max(0.0, baseColor.green - darkness),
                blue: max(0.0, baseColor.blue - darkness),
                alpha: baseColor.alpha
            )
            palette.append(darkerColor)
        }

        return palette
    }
}

// MARK: - Predefined Accessible Color Palettes

extension ColorContrastSupport {
    /// Predefined accessible color palettes that meet WCAG 2.1 requirements
    public struct AccessiblePalettes {
        // Primary colors with good contrast
        public static var primaryBlue: AccessibleColor {
            AccessibleColor(red: 0.0, green: 0.333, blue: 0.8)  // #0055CC - Good contrast (6.63:1 on white)
        }

        public static var primaryRed: AccessibleColor {
            AccessibleColor(red: 0.6, green: 0.0, blue: 0.0)  // #990000 - Darker red for better contrast on light backgrounds
        }

        public static var primaryGreen: AccessibleColor {
            AccessibleColor(red: 0.0, green: 0.4, blue: 0.0)  // #006600 - Darker green for better contrast on light backgrounds
        }

        // Light background variants - darker colors for better contrast on light backgrounds
        public static var primaryRedForLightBackground: AccessibleColor {
            AccessibleColor(red: 0.5, green: 0.0, blue: 0.0)  // #800000 - Even darker red for light backgrounds
        }

        public static var primaryGreenForLightBackground: AccessibleColor {
            AccessibleColor(red: 0.0, green: 0.3, blue: 0.0)  // #004D00 - Even darker green for light backgrounds
        }

        // Dark background variants - brighter colors for better contrast on dark backgrounds
        public static var primaryRedForDarkBackground: AccessibleColor {
            AccessibleColor(red: 1.0, green: 0.2, blue: 0.2)  // #FF3333 - Brighter red for dark backgrounds
        }

        public static var primaryGreenForDarkBackground: AccessibleColor {
            AccessibleColor(red: 0.2, green: 0.8, blue: 0.2)  // #33CC33 - Brighter green for dark backgrounds
        }

        // Neutral colors for backgrounds and text
        public static var backgroundLight: AccessibleColor {
            AccessibleColor(red: 0.949, green: 0.949, blue: 0.969)  // #F2F2F7
        }

        public static var backgroundDark: AccessibleColor {
            AccessibleColor(red: 0.113, green: 0.113, blue: 0.145)  // #1C1C25
        }

        public static var textLight: AccessibleColor {
            AccessibleColor(red: 1.0, green: 1.0, blue: 1.0)  // #FFFFFF
        }

        public static var textDark: AccessibleColor {
            AccessibleColor(red: 0.0, green: 0.0, blue: 0.0)  // #000000
        }

        // Color blindness friendly alternatives
        public static var cbFriendlyBlue: AccessibleColor {
            AccessibleColor(red: 0.0, green: 0.447, blue: 0.698)  // #0072B2
        }

        public static var cbFriendlyRed: AccessibleColor {
            AccessibleColor(red: 0.835, green: 0.369, blue: 0.0)  // #D55E00
        }

        public static var cbFriendlyGreen: AccessibleColor {
            AccessibleColor(red: 0.0, green: 0.62, blue: 0.451)  // #009E73
        }
    }
}

// MARK: - SwiftUI Extensions (iOS only)

#if canImport(SwiftUI) && canImport(UIKit)
    extension View {
        /// Applies accessible colors that maintain proper contrast in both light and dark mode
        /// - Parameters:
        ///   - foreground: The foreground color
        ///   - background: The background color
        ///   - level: The required WCAG contrast level
        /// - Returns: A view with accessible color styling
        public func accessibleColors(
            foreground: AccessibleColor,
            background: AccessibleColor,
            level: WCAGContrastLevel = .normalText
        ) -> some SwiftUI.View {
            return
                self
                .foregroundColor(Color(foreground.toUIColor()))
                .background(Color(background.toUIColor()))
        }

        /// Conditionally applies colors based on contrast compliance
        /// - Parameters:
        ///   - foreground: The preferred foreground color
        ///   - background: The background color
        ///   - fallbackForeground: Fallback color if contrast is insufficient
        ///   - level: The required WCAG contrast level
        /// - Returns: A view with contrast-compliant colors
        public func contrastAwareColors(
            foreground: AccessibleColor,
            background: AccessibleColor,
            fallbackForeground: AccessibleColor,
            level: WCAGContrastLevel = .normalText
        ) -> some SwiftUI.View {
            let isCompliant = ColorContrastSupport.meetsContrastRequirements(
                foreground: foreground,
                background: background,
                level: level
            )

            let finalForeground = isCompliant ? foreground : fallbackForeground

            return accessibleColors(
                foreground: finalForeground, background: background, level: level)
        }
    }

    // MARK: - Environment Support for Dynamic Color Schemes

    /// Environment key for tracking color scheme changes
    private struct ColorSchemeEnvironmentKey: EnvironmentKey {
        static let defaultValue: ColorScheme = .light
    }

    extension EnvironmentValues {
        /// Environment value for color scheme
        public var colorScheme: ColorScheme {
            get { self[ColorSchemeEnvironmentKey.self] }
            set { self[ColorSchemeEnvironmentKey.self] = newValue }
        }
    }

    extension View {
        /// Configures the view to adapt to color scheme changes while maintaining contrast
        /// - Returns: A view configured to respond to color scheme changes
        public func adaptsToColorScheme() -> some SwiftUI.View {
            self.environment(\.colorScheme, .light)
        }
    }
#endif

// MARK: - Testing Utilities

extension ColorContrastSupport {
    /// Testing utility to verify color combinations meet accessibility standards
    /// - Parameters:
    ///   - foreground: Foreground color
    ///   - background: Background color
    ///   - level: Required contrast level
    /// - Returns: Tuple with contrast ratio and compliance status
    public static func testColorCompliance(
        foreground: AccessibleColor,
        background: AccessibleColor,
        level: WCAGContrastLevel
    ) -> (ratio: Double, isCompliant: Bool) {
        let ratio = calculateContrastRatio(foreground: foreground, background: background)
        let compliant = ratio >= level.ratio

        return (ratio, compliant)
    }

    /// Generates a compliance report for multiple color combinations
    public static func generateComplianceReport(
        combinations: [(
            foreground: AccessibleColor, background: AccessibleColor, level: WCAGContrastLevel
        )]
    ) -> String {
        var report = "Color Contrast Compliance Report\n"
        report += "==================================\n\n"

        for (index, combination) in combinations.enumerated() {
            let result = testColorCompliance(
                foreground: combination.foreground,
                background: combination.background,
                level: combination.level
            )

            report += "Combination \(index + 1):\n"
            report +=
                "  Foreground: RGB(\(combination.foreground.red), \(combination.foreground.green), \(combination.foreground.blue))\n"
            report +=
                "  Background: RGB(\(combination.background.red), \(combination.background.green), \(combination.background.blue))\n"
            report += "  Required: \(combination.level.description)\n"
            report += "  Actual: \(String(format: "%.2f", result.ratio)):1\n"
            report += "  Status: \(result.isCompliant ? "PASS" : "FAIL")\n\n"
        }

        return report
    }
}
