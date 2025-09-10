import Foundation
import SoundToLightTherapy
import SwiftUI

@main
public struct SoundToLightTherapyApplication: App {
    public init() {}

    public var body: some Scene {
        WindowGroup("Sound to Light Therapy") {
            TherapyView()
                .padding()
        }
    }
}
