import Foundation
import SwiftUI

/// Main therapy view with comprehensive accessibility support
public struct DynamicTypeTestView: SwiftUI.View {

    public init() {}

    public var body: some SwiftUI.View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Text("Dynamic Type Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)

                Text(
                    "This view tests how text scales with different content size categories. Change your device's text size settings to see the effect."
                )
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }

            Divider()
                .padding(.horizontal)

            VStack(spacing: 15) {
                Text("Sample Text Sizes")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Title: Dynamic Type Sample")
                        .font(.title)

                    Text("Headline: Important Information")
                        .font(.headline)

                    Text("Body: This is the standard body text that most content uses.")
                        .font(.body)

                    Text("Caption: Small detail text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            Divider()
                .padding(.horizontal)

            VStack(spacing: 15) {
                Text("Content Size Categories")
                    .font(.title2)
                    .padding(10)

                VStack(spacing: 8) {
                    HStack {
                        Text("Large:")
                            .font(.subheadline)
                        Text("Sample")
                            .font(.body)
                            .environment(\.sizeCategory, .large)
                        Spacer()
                    }

                    HStack {
                        Text("Extra Large:")
                            .font(.subheadline)
                        Text("Sample")
                            .font(.body)
                            .environment(\.sizeCategory, .extraLarge)
                        Spacer()
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }
}

// Simplified preview without problematic ForEach
struct DynamicTypeTestView_Previews: PreviewProvider {
    static var previews: some View {
        DynamicTypeTestView()
            .previewDisplayName("Dynamic Type Test")
    }
}
