import DefaultBackend
import Foundation
import SoundToLightTherapy
import SwiftCrossUI

// Create the main app instance using SwiftCrossUI
@main
struct SoundToLightTherapyApplication: App {
    typealias Backend = DefaultBackend

    var body: some Scene {
        WindowGroup("Sound to Light Therapy") {
            TherapyView()
                .padding()
        }
    }
}
