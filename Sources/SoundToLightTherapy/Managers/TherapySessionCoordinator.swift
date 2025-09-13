import Foundation

public actor TherapySessionCoordinator {
    private let audioCaptureManager = AudioCaptureManager()
    private let frequencyDetector = FrequencyDetector()
    private let flashlightController = FlashlightController()

    private var isSessionActive: Bool = false
    private var audioStream: AsyncStream<[Float]>?
    private var detectionTask: Task<Void, Never>?

    // Session configuration
    private var targetFrequency: Float = 10.0
    private var sessionDuration: TimeInterval = 300.0
    private var currentFrequency: Float = 0.0
    private var sessionStartTime: Date?

    public init() {}

    public enum TherapySessionError: Error {
        case sessionAlreadyActive
        case sessionNotActive
        case audioCaptureFailed
        case frequencyDetectionFailed
        case flashlightControlFailed
    }

    public func startAudioResponsiveSession(duration: TimeInterval = 300.0) async throws {
        guard !isSessionActive else {
            throw TherapySessionError.sessionAlreadyActive
        }

        // Configure session parameters (no manual target frequency)
        self.sessionDuration = duration
        self.sessionStartTime = Date()
        self.targetFrequency = 0.0  // Will be determined by audio input

        do {
            // Enable screen wake lock to prevent device from sleeping
            try await ScreenWakeLock.shared.enableWakeLock()

            // Start audio capture
            audioStream = try await audioCaptureManager.startCapture()
            isSessionActive = true

            // Start pure audio-responsive processing
            detectionTask = Task {
                await processAudioResponsiveMode()
            }

            // Generate haptic feedback for session start
            _ = await HapticFeedbackSupport.generate(.mediumImpact, respectReducedMotion: true)

            print("✅ Audio-responsive therapy session started - duration: \(duration)s, wake lock enabled")
        } catch {
            await stopSession()
            throw TherapySessionError.audioCaptureFailed
        }
    }

    // Keep original method for backward compatibility
    public func startSession(targetFrequency: Float = 10.0, duration: TimeInterval = 300.0) async throws {
        guard !isSessionActive else {
            throw TherapySessionError.sessionAlreadyActive
        }

        // Configure session parameters
        self.targetFrequency = targetFrequency
        self.sessionDuration = duration
        self.sessionStartTime = Date()

        do {
            // Enable screen wake lock to prevent device from sleeping
            try await ScreenWakeLock.shared.enableWakeLock()

            // Start audio capture
            audioStream = try await audioCaptureManager.startCapture()
            isSessionActive = true

            // Start frequency detection and flashlight control
            detectionTask = Task {
                await processAudioAndControlFlashlight()
            }

            // Generate haptic feedback for session start
            _ = await HapticFeedbackSupport.generate(.mediumImpact, respectReducedMotion: true)

            print("✅ Therapy session started successfully - target: \(targetFrequency)Hz, duration: \(duration)s, wake lock enabled")
        } catch {
            await stopSession()
            throw TherapySessionError.audioCaptureFailed
        }
    }

    public func stopSession() async {
        isSessionActive = false
        detectionTask?.cancel()
        detectionTask = nil
        await audioCaptureManager.stopCapture()
        audioStream = nil

        // Turn off flashlight
        do {
            try await flashlightController.setFlashlight(false)
        } catch {
            print("Warning: Failed to turn off flashlight during session stop")
        }

        // Disable screen wake lock
        do {
            try await ScreenWakeLock.shared.disableWakeLock()
        } catch {
            print("Warning: Failed to disable wake lock: \(error)")
        }

        // Generate haptic feedback for session stop
        _ = await HapticFeedbackSupport.generate(.lightImpact, respectReducedMotion: true)

        print("Therapy session stopped, wake lock disabled")
    }

    // MARK: - Pure Audio-Responsive Processing

    private func processAudioResponsiveMode() async {
        guard let audioStream = audioStream else {
            print("❌ No audio stream available for processing")
            return
        }

        print("🎵 Starting pure audio-responsive mode - flashlight syncs directly to detected audio")

        var lastFlashlightToggle = Date()

        // Start with flashlight off
        try? await flashlightController.setFlashlight(false)

        for await audioBuffer in audioStream {
            guard !Task.isCancelled else { break }
            guard isSessionActive else { break }

            do {
                // Perform advanced frequency analysis
                let result = try await frequencyDetector.detectFrequencyWithConfidence(from: audioBuffer)

                // Update current frequency for UI display (use the mapped therapeutic frequency)
                currentFrequency = result.dominantFrequency

                // Use the therapeutic frequency directly for flashlight control
                let flashlightFreq = result.therapeuticFrequency

                print("🔊 Audio: \(result.dominantFrequency)Hz → Flashlight: \(flashlightFreq)Hz")

                // Calculate strobe interval based on detected therapeutic frequency
                let strobeInterval = 1.0 / (Double(flashlightFreq) * 2.0)  // *2 for on/off cycle

                let now = Date()
                let timeSinceLastToggle = now.timeIntervalSince(lastFlashlightToggle)

                if timeSinceLastToggle >= strobeInterval {
                    // Rapid toggle for real-time audio response
                    try await flashlightController.rapidToggle()
                    lastFlashlightToggle = now

                    print("💡 Flashlight toggled at \(flashlightFreq)Hz")
                }

            } catch FrequencyDetector.FrequencyDetectionError.frequencyOutOfRange {
                print("⚠️ Audio frequency outside detectable range")
                // Turn off flashlight when no valid audio detected
                try? await flashlightController.setFlashlight(false)
            } catch {
                print("Error in audio processing: \(error)")
                // Continue processing, don't stop session
            }

            // Check if session duration has been reached
            if let startTime = sessionStartTime,
               Date().timeIntervalSince(startTime) >= sessionDuration {
                print("⏰ Session duration reached, stopping session")
                await stopSession()
                break
            }
        }

        // Ensure flashlight is off when processing ends
        try? await flashlightController.setFlashlight(false)
        print("🔆 Audio-responsive mode completed")
    }

    private func processAudioAndControlFlashlight() async {
        guard let audioStream = audioStream else {
            print("❌ No audio stream available for processing")
            return
        }

        print("🎵 Starting audio processing loop - target frequency: \(targetFrequency)Hz")

        var flashlightState = false
        var lastFlashlightToggle = Date()

        // Calculate target interval between flashlight toggles (in seconds)
        let targetInterval = 1.0 / (Double(targetFrequency) * 2.0) // *2 because on+off = 1 cycle

        for await audioBuffer in audioStream {
            guard !Task.isCancelled else { break }
            guard isSessionActive else { break }

            do {
                // Detect current frequency from audio
                let detectedFrequency = try await frequencyDetector.detectFrequency(from: audioBuffer)
                currentFrequency = detectedFrequency

                print("🔊 Detected: \(detectedFrequency)Hz, Target: \(targetFrequency)Hz")

                // Use target frequency for therapeutic effect (not detected frequency)
                // This provides consistent therapy regardless of ambient sound
                let now = Date()
                let timeSinceLastToggle = now.timeIntervalSince(lastFlashlightToggle)

                if timeSinceLastToggle >= targetInterval {
                    // Toggle flashlight at target frequency
                    flashlightState.toggle()
                    try await flashlightController.setFlashlight(flashlightState)
                    lastFlashlightToggle = now

                    print("💡 Flashlight: \(flashlightState ? "ON" : "OFF") at \(targetFrequency)Hz")
                }

            } catch FrequencyDetector.FrequencyDetectionError.frequencyOutOfRange {
                // Frequency is outside therapeutic range, continue with target frequency
                print("⚠️ Detected frequency outside range, using target frequency")
            } catch {
                print("Error in frequency detection: \(error)")
                // Continue with target frequency even if detection fails
            }

            // Check if session duration has been reached
            if let startTime = sessionStartTime,
               Date().timeIntervalSince(startTime) >= sessionDuration {
                print("⏰ Session duration reached, stopping session")
                await stopSession()
                break
            }
        }
    }

    public func getSessionState() async -> Bool {
        return isSessionActive
    }

    public func getCurrentFrequency() async -> Float {
        return currentFrequency
    }

    public func getSessionProgress() async -> Double {
        guard let startTime = sessionStartTime else { return 0.0 }
        let elapsed = Date().timeIntervalSince(startTime)
        return min(1.0, elapsed / sessionDuration)
    }

    public func getTargetFrequency() async -> Float {
        return targetFrequency
    }

}
