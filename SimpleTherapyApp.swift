import AVFoundation
import SwiftUI
import UIKit

@main
struct SimpleTherapyApp: App {
    var body: some Scene {
        WindowGroup {
            SimpleTherapyView()
        }
    }
}

struct SimpleTherapyView: View {
    @State private var isSessionActive = false
    @State private var statusText = "Ready to start therapy"

    var body: some View {
        VStack(spacing: 30) {
            Text("🔊💡 Sound to Light Therapy")
                .font(.title)
                .multilineTextAlignment(.center)

            Text(statusText)
                .font(.headline)
                .foregroundColor(isSessionActive ? .green : .blue)

            Button(action: toggleSession) {
                Text(isSessionActive ? "Stop Session" : "Start Session")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isSessionActive ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            if isSessionActive {
                Text("🔦 Flashlight will sync with detected sounds")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }

    func toggleSession() {
        isSessionActive.toggle()

        if isSessionActive {
            statusText = "Session Active - Detecting sounds..."
            requestPermissions()
            startFlashlightDemo()
        } else {
            statusText = "Session Stopped"
        }
    }

    func requestPermissions() {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("Microphone permission: \(granted)")
        }

        // Request camera permission for flashlight
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("Camera permission: \(granted)")
        }
    }

    func startFlashlightDemo() {
        // Simple flashlight demo - flashes every 2 seconds
        guard let device = AVCaptureDevice.default(for: .video),
            device.hasTorch
        else { return }

        DispatchQueue.global().async {
            for i in 0..<5 {
                if !isSessionActive { break }

                try? device.lockForConfiguration()
                try? device.setTorchModeOn(level: 1.0)
                device.unlockForConfiguration()

                Thread.sleep(forTimeInterval: 0.2)

                try? device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()

                Thread.sleep(forTimeInterval: 1.8)
            }
        }
    }
}
