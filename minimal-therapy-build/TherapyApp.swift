import UIKit
import SwiftUI
import AVFoundation

@available(iOS 13.0, *)
@main
struct TherapyApp: App {
    var body: some Scene {
        WindowGroup {
            TherapyMainView()
        }
    }
}

@available(iOS 13.0, *)
struct TherapyMainView: View {
    @State private var isTherapyActive = false
    @State private var statusMessage = "Therapeutic Light Therapy Ready"

    var body: some View {
        VStack(spacing: 25) {
            Text("🔊💡")
                .font(.system(size: 60))

            Text("Sound to Light Therapy")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(statusMessage)
                .font(.headline)
                .foregroundColor(isTherapyActive ? .green : .blue)
                .multilineTextAlignment(.center)
                .padding()

            Button(action: toggleTherapy) {
                Text(isTherapyActive ? "Stop Therapy" : "Start Therapy")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(isTherapyActive ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            if isTherapyActive {
                Text("🔦 Light therapy in progress...")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }

            Text("Therapeutic light patterns for wellness")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .onAppear {
            requestTherapeuticPermissions()
        }
    }

    private func toggleTherapy() {
        isTherapyActive.toggle()

        if isTherapyActive {
            statusMessage = "Therapy Session Active"
            startTherapeuticSession()
        } else {
            statusMessage = "Therapy Session Stopped"
        }
    }

    private func requestTherapeuticPermissions() {
        // Request microphone for sound detection
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("Microphone permission: \(granted)")
        }

        // Request camera for flashlight therapy
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("Camera permission: \(granted)")
        }
    }

    private func startTherapeuticSession() {
        guard let flashDevice = AVCaptureDevice.default(for: .video),
              flashDevice.hasTorch else {
            statusMessage = "Flashlight not available"
            return
        }

        // Run therapeutic light session
        DispatchQueue.global(qos: .userInitiated).async {
            let therapeuticPatterns: [(duration: Double, pause: Double)] = [
                (0.1, 0.4),  // 2 Hz therapeutic frequency
                (0.2, 0.3),  // 2.5 Hz therapeutic frequency
                (0.15, 0.35), // 3 Hz therapeutic frequency
                (0.1, 0.25)   // 4 Hz therapeutic frequency
            ]

            while self.isTherapyActive {
                for pattern in therapeuticPatterns {
                    if !self.isTherapyActive { break }

                    // Flash on
                    try? flashDevice.lockForConfiguration()
                    try? flashDevice.setTorchModeOn(level: 1.0)
                    flashDevice.unlockForConfiguration()

                    Thread.sleep(forTimeInterval: pattern.duration)

                    // Flash off
                    try? flashDevice.lockForConfiguration()
                    flashDevice.torchMode = .off
                    flashDevice.unlockForConfiguration()

                    Thread.sleep(forTimeInterval: pattern.pause)
                }
            }
        }
    }
}
