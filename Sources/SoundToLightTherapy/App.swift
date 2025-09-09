import Foundation
import SwiftUI

// Pure SwiftUI implementation for iOS deployment
@main
public struct SoundToLightTherapyApplication: App {
    public var body: some Scene {
        WindowGroup("Sound to Light Therapy") {
            TherapyView()
                .padding()
        }
    }

    public init() {}
}
