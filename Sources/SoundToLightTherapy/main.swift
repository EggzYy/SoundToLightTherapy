import Foundation
import SoundToLightTherapy
import SwiftUI

// Pure SwiftUI implementation for iOS deployment
@main
struct SoundToLightTherapyApplication: App {
    var body: some Scene {
        WindowGroup("Sound to Light Therapy") {
            TherapyView()
                .padding()
        }
    }
}
