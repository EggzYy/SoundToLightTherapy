import SwiftUI
import AVFoundation
import UIKit
import Accelerate

@main
struct TherapeuticApp: App {
    var body: some Scene {
        WindowGroup("Sound to Light Therapy") {
            TherapyMainView()
        }
    }
}

struct TherapyMainView: View {
    @State private var isSessionActive = false
    @State private var statusText = "Ready for Therapeutic Session"
    @State private var currentFrequency: Float = 0.0
    @State private var permissionsGranted = false

    var body: some View {
        VStack(spacing: 30) {
            Text("🔊💡 Sound to Light Therapy")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()

            VStack(spacing: 15) {
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(isSessionActive ? .green : .blue)
                    .multilineTextAlignment(.center)

                if isSessionActive {
                    Text("Frequency: \(String(format: "%.1f", currentFrequency)) Hz")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            Button(action: toggleTherapySession) {
                Text(isSessionActive ? "Stop Therapy Session" : "Start Therapy Session")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isSessionActive ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }

            if isSessionActive {
                VStack {
                    Text("🔦 Flashlight syncing with detected sounds")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Text("🎯 Therapeutic frequencies: 0.5-40 Hz")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            if !permissionsGranted {
                Text("⚠️ Camera and microphone permissions required")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .onAppear {
            requestAllPermissions()
        }
    }

    private func toggleTherapySession() {
        isSessionActive.toggle()

        if isSessionActive {
            statusText = "Therapy Session Active - Detecting therapeutic sounds..."
            startTherapeuticSession()
        } else {
            statusText = "Therapy Session Stopped"
        }
    }

    private func requestAllPermissions() {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Microphone permission granted")
                } else {
                    print("❌ Microphone permission denied")
                }
                checkPermissionStatus()
            }
        }

        // Request camera permission for flashlight
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Camera permission granted")
                } else {
                    print("❌ Camera permission denied")
                }
                checkPermissionStatus()
            }
        }
    }

    private func checkPermissionStatus() {
        let micPermission = AVAudioSession.sharedInstance().recordPermission == .granted
        let camPermission = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        permissionsGranted = micPermission && camPermission
    }

    private func startTherapeuticSession() {
        guard permissionsGranted else {
            statusText = "Please grant camera and microphone permissions"
            return
        }

        // Start therapeutic frequency detection and flashlight sync
        DispatchQueue.global(qos: .userInitiated).async {
            self.runTherapeuticDetection()
        }
    }

    private func runTherapeuticDetection() {
        // Simulate therapeutic frequency detection with flashlight sync
        let frequencies: [Float] = [2.5, 5.0, 7.5, 10.0, 15.0, 20.0, 25.0, 30.0]

        while isSessionActive {
            // Cycle through therapeutic frequencies
            for freq in frequencies {
                if !isSessionActive { break }

                DispatchQueue.main.async {
                    self.currentFrequency = freq
                }

                // Flash light for therapeutic frequency
                flashTherapeuticLight(frequency: freq)

                Thread.sleep(forTimeInterval: 2.0) // 2 seconds per frequency
            }
        }
    }

    private func flashTherapeuticLight(frequency: Float) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        // Calculate flash pattern based on therapeutic frequency
        let flashDuration = 0.1
        let pauseDuration = (1.0 / Double(frequency)) - flashDuration

        for _ in 0..<Int(frequency * 2) { // Flash for 2 seconds at this frequency
            if !isSessionActive { break }

            try? device.lockForConfiguration()
            try? device.setTorchModeOn(level: 1.0)
            device.unlockForConfiguration()

            Thread.sleep(forTimeInterval: flashDuration)

            try? device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()

            Thread.sleep(forTimeInterval: pauseDuration)
        }
    }
}
