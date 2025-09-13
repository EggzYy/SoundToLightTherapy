import Foundation
import SwiftUI

/// Main therapy view with comprehensive accessibility support
public struct TherapyView: SwiftUI.View {
    // State properties for data
    @State private var targetFrequency: Float = 10.0
    @State private var sessionDuration: TimeInterval = 300
    @State private var isSessionActive: Bool = false
    @State private var currentFrequency: Float = 0.0
    @State private var sessionProgress: Double = 0.0
    @State private var lastAnnouncedProgress: Int = -1
    @State private var isWakeLockActive: Bool = false

    // Shared session coordinator instance
    private let sessionCoordinator = TherapySessionCoordinator()

    #if canImport(UIKit)
    // Wake lock lifecycle manager for handling app lifecycle events
    @StateObject private var wakeLockManager = WakeLockLifecycleManager()
    #endif

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Header section
            headerSection

            // Audio responsiveness display section
            audioResponseSection

            // Session control section
            sessionControlSection

            // Status display section
            statusDisplaySection

            // Emergency stop section
            emergencyStopSection

            // Settings section
            settingsSection
        }
        .padding()
        .frame(maxWidth: 600)
        .background(accessibleColorToColor(ColorContrastSupport.AccessiblePalettes.backgroundLight))
        // TODO: Add accessibility support when SwiftCrossUI implements accessibility APIs
        // TODO: Add onChange support when SwiftCrossUI supports it
        // Removed onChange calls due to SwiftCrossUI compatibility issues
    }

    // MARK: - View Components
    private var headerSection: some View {
        VStack {
            Text("Sound to Light Therapy")
                .font(.title)
            // TODO: Add accessibility traits when SwiftCrossUI supports them

            Text("Convert audio frequencies to light patterns")
                .font(.subheadline)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            // TODO: Add accessibility label when SwiftCrossUI supports them
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    private var audioResponseSection: some View {
        VStack(spacing: 15) {
            Text("🎵 Audio-Responsive Light Therapy")
                .font(.headline)
                .foregroundColor(.blue)

            Text("Flashlight automatically syncs to detected audio frequencies")
                .font(.subheadline)
                .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                .multilineTextAlignment(.center)

            // Real-time audio analysis display
            VStack(spacing: 8) {
                HStack {
                    Text("Input Audio:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    Spacer()
                    Text("\(String(format: "%.1f", currentFrequency)) Hz")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                HStack {
                    Text("Therapeutic Output:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    Spacer()
                    Text("\(String(format: "%.1f", currentFrequency * 0.1)) Hz")  // Show mapped frequency
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                // Audio activity indicator
                HStack {
                    Text("Audio Activity:")
                        .font(.caption)
                        .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                    Spacer()
                    Circle()
                        .fill(currentFrequency > 10 ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                        .scaleEffect(currentFrequency > 10 ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentFrequency)
                }
            }
            .padding(.horizontal)
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    private var sessionControlSection: some View {
        HStack(spacing: 20) {
            Button("Start Session") {
                Task {
                    await startSession()
                }
            }
            .disabled(isSessionActive)
            // TODO: Add accessibility labels and hints when SwiftCrossUI supports them
            .withHapticFeedback(.mediumImpact, respectReducedMotion: true)

            Button("Stop Session") {
                Task {
                    await stopSession()
                }
            }
            .disabled(!isSessionActive)
            // TODO: Add accessibility labels and hints when SwiftCrossUI supports them
            .withHapticFeedback(.lightImpact, respectReducedMotion: true)
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    private var statusDisplaySection: some View {
        VStack(spacing: 10) {
            Text("Session Status: \(isSessionActive ? "Active" : "Inactive")")
                .font(.headline)
                .foregroundColor(isSessionActive ? .green : Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            // TODO: Add accessibility labels and traits when SwiftCrossUI supports them

            Text("Current Frequency: \(String(format: "%.1f", currentFrequency)) Hz")
                .font(.body)
            // TODO: Add accessibility labels and traits when SwiftCrossUI supports them

            Text("Progress: \(Int(sessionProgress * 100))%")
                .font(.body)
            // TODO: Add accessibility labels and traits when SwiftCrossUI supports them

            ProgressView(value: sessionProgress)
            // TODO: Add accessibility support for progress view when SwiftCrossUI supports them

            // Wake lock status indicator
            HStack {
                Text("Screen Lock:")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                Spacer()
                Text(isWakeLockActive ? "🔓 Disabled" : "🔒 Enabled")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isWakeLockActive ? .green : Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
            }
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    private var emergencyStopSection: some View {
        Button("EMERGENCY STOP") {
            Task {
                await emergencyStop()
            }
        }
        .foregroundColor(.white)
        .background(Color.red)
        .cornerRadius(8)
        // TODO: Add accessibility labels, hints, and identifiers when SwiftCrossUI supports them
        .withHapticFeedback(.error, respectReducedMotion: false)  // Always provide haptic for emergency
    }

    private var settingsSection: some View {
        VStack {
            Text("Session Duration: \(Int(sessionDuration)) seconds")
                .font(.headline)
            // TODO: Add accessibility labels and traits when SwiftCrossUI supports them

            Slider(value: $sessionDuration, in: 60.0...600.0)
                // TODO: Add accessibility support for slider when SwiftCrossUI supports them
                .withHapticFeedback(.selection, respectReducedMotion: true)

            HStack {
                Text("60 sec")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                // TODO: Add accessibility label when SwiftCrossUI supports them

                Spacer()

                Text("600 sec")
                    .font(.caption)
                    .foregroundColor(Color(hue: 0.5, saturation: 0.5, brightness: 0.5, opacity: 1.0))
                // TODO: Add accessibility label when SwiftCrossUI supports them
            }
        }
        // TODO: Add accessibility grouping when SwiftCrossUI supports them
    }

    // MARK: - Session Management
    private func startSession() async {
        do {
            try await sessionCoordinator.startAudioResponsiveSession(duration: sessionDuration)
            isSessionActive = true

            // Start updating UI with real-time data
            Task {
                await updateSessionDataLoop()
            }

            print("✅ Therapy session started successfully!")
            // Generate haptic feedback for session start
            _ = HapticFeedbackSupport.generate(.mediumImpact, respectReducedMotion: true)
        } catch {
            print("❌ Failed to start session: \(error)")
            // Generate error haptic feedback
            _ = HapticFeedbackSupport.generate(.error, respectReducedMotion: true)
        }
    }

    private func stopSession() async {
        await sessionCoordinator.stopSession()
        isSessionActive = false
        print("🛑 Therapy session stopped")
        // Generate haptic feedback for session stop
        _ = HapticFeedbackSupport.generate(.lightImpact, respectReducedMotion: true)
    }

    private func emergencyStop() async {
        await sessionCoordinator.stopSession()
        isSessionActive = false

        // Force disable wake lock for emergency stop
        await ScreenWakeLock.shared.forceDisableWakeLock()

        await AccessibilityAnnouncer.shared.announceEmergencyStop()
        // Always generate strong haptic for emergency stop
        _ = HapticFeedbackSupport.generate(.heavyImpact, respectReducedMotion: false)
    }

    private func announceProgressIfNeeded(_ progress: Double) async {
        let currentPercent = Int(progress * 100)
        // Announce progress every 25% to avoid overwhelming VoiceOver users
        if currentPercent != lastAnnouncedProgress && currentPercent % 25 == 0 {
            lastAnnouncedProgress = currentPercent
            await AccessibilityAnnouncer.shared.announceSessionProgress(progress)
        }
    }

    private func updateSessionDataLoop() async {
        while isSessionActive {
            await updateSessionState()
            try? await Task.sleep(nanoseconds: 250_000_000) // Update every 250ms
        }
    }

    private func updateSessionState() async {
        let activeState = await sessionCoordinator.getSessionState()
        isSessionActive = activeState

        if activeState {
            currentFrequency = await sessionCoordinator.getCurrentFrequency()
            sessionProgress = await sessionCoordinator.getSessionProgress()

            // Announce progress if needed
            await announceProgressIfNeeded(sessionProgress)
        }

        // Update wake lock status
        isWakeLockActive = await ScreenWakeLock.shared.isActive()
    }

    // MARK: - Color Conversion Helper
    private func accessibleColorToColor(_ accessibleColor: AccessibleColor) -> Color {
        return Color(
            red: Double(accessibleColor.red),
            green: Double(accessibleColor.green),
            blue: Double(accessibleColor.blue),
            opacity: Double(accessibleColor.alpha)
        )
    }
}
