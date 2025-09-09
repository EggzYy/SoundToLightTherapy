import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
/// Comprehensive test view to verify Dynamic Type support across all content size categories
/// and text styles. This view demonstrates the scalable font system and ensures that
/// text scales appropriately for accessibility settings.
///
/// - Note: This view is primarily for development and testing purposes to validate
///   the Dynamic Type implementation before deployment.
public struct DynamicTypeTestView: View {
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Dynamic Type Support Test")
                    .scalableFont(.title)
                    .padding(20)
                
                textStylesSection
                sizeCategoriesSection
            }
            .padding(16)
        }
        .frame(minWidth: 800)
        .adaptsToContentSizeCategory()
    }
    
    // MARK: - Platform-Specific Sections
    
    private var textStylesSection: some View {
        ForEach(TextStyle.allCases, id: \.self) { textStyle in
            VStack {
                Text("\(textStyle.rawValue)")
                    .scalableFont(.headline)
                    .foregroundColor(accessibleColorToColor(ColorContrastSupport.AccessiblePalettes.primaryBlue))
                
                Text("Sample text in \(textStyle.rawValue) style")
                    .scalableFont(textStyle)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }
    
    private var sizeCategoriesSection: some View {
        VStack {
            Text("Content Size Categories")
                .scalableFont(.title2)
                .padding(10)
            
            ForEach(ContentSizeCategory.allCases, id: \.self) { sizeCategory in
                HStack {
                    Text("\(sizeCategory.rawValue):")
                        .scalableFont(.subheadline)
                    
                    Text("Sample")
                        .scalableFont(.body)
                        .environment(\.sizeCategory, sizeCategory.toPlatformSizeCategory())
                    
                    Spacer()
                }
                .padding(5)
            }
        }
        .padding(16)
    }
    
    // MARK: - Color Conversion Helper
    private func accessibleColorToColor(_ accessibleColor: AccessibleColor) -> Color {
        if let uiColor = accessibleColor.toPlatformColor() as? UIColor {
            return Color(uiColor)
        }
        return Color.black // Fallback color
    }
}
#endif

#if DEBUG && canImport(SwiftUI)
// Preview for testing all content size categories
struct DynamicTypeTestView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach(ContentSizeCategory.allCases.prefix(5), id: \.self) { sizeCategory in
                DynamicTypeTestView()
                    .environment(\.sizeCategory, sizeCategory.toPlatformSizeCategory())
                    .previewDisplayName("\(sizeCategory.rawValue)")
            }
            
            // Test extreme sizes
            DynamicTypeTestView()
                .environment(\.sizeCategory, ContentSizeCategory.extraSmall.toPlatformSizeCategory())
                .previewDisplayName("Extra Small")
            
            DynamicTypeTestView()
                .environment(\.sizeCategory, ContentSizeCategory.accessibilityExtraExtraExtraLarge.toPlatformSizeCategory())
                .previewDisplayName("Accessibility XXXL")
        }
    }
}
#endif