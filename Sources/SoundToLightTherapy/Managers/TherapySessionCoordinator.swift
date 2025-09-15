import Foundation

public actor TherapySessionCoordinator {
    private let audioCaptureManager = AudioCaptureManager()
    private let frequencyDetector = FrequencyDetector()
    private let flashlightController = FlashlightController()
    private let precisionStrobeController = PrecisionStrobeController()

    private var isSessionActive: Bool = false
    private var audioStream: AsyncStream<[Float]>?
    private var detectionTask: Task<Void, Never>?

    // Session configuration
    private var targetFrequency: Float = 10.0
    private var sessionDuration: TimeInterval = 300.0
    private var currentFrequency: Float = 0.0
    private var sessionStartTime: Date?
    
    // Pattern-based session state
    private var currentSessionPattern: SessionPattern? = nil
    private var patternProgressTask: Task<Void, Never>? = nil
    private var currentPatternSegment: SessionPattern.TherapySegment? = nil

    public init() {
        // Note: Hardware calibration will be performed when needed, not during init
        // This prevents unwanted strobing during app startup
    }
    
    /// Perform hardware calibration when explicitly requested or when starting a session
    private func performInitialCalibrationIfNeeded() async {
        do {
            // Check if we have recent calibration data
            let capabilities = try await precisionStrobeController.getHardwareCapabilities()
            let timeSinceCalibration = Date().timeIntervalSince(capabilities.benchmarkDate)
            
            // If calibration is older than 24 hours, re-calibrate
            if timeSinceCalibration > 86400 {
                print("🔧 Performing background hardware calibration...")
                _ = try await precisionStrobeController.performHardwareBenchmark()
                print("✅ Background hardware calibration completed")
            } else {
                print("✅ Using existing calibration data (age: \(Int(timeSinceCalibration/3600))h)")
            }
        } catch {
            print("⚠️ Calibration check failed: \(error)")
        }
    }

    public enum TherapySessionError: Error {
        case sessionAlreadyActive
        case sessionNotActive
        case audioCaptureFailed
        case frequencyDetectionFailed
        case flashlightControlFailed
        case invalidSessionPattern
        case patternValidationFailed([SessionPattern.ValidationError])
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

            // Ensure flashlight starts in OFF state
            try await flashlightController.setFlashlight(false)
            print("🔦 Flashlight initialized to OFF state")

            // Perform calibration check in background (non-blocking)
            Task {
                await performInitialCalibrationIfNeeded()
            }

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
    
    public func startPatternBasedSession(pattern: SessionPattern) async throws {
        guard !isSessionActive else {
            throw TherapySessionError.sessionAlreadyActive
        }
        
        // Validate the pattern before starting
        let validation = pattern.validate()
        guard validation.isValid else {
            throw TherapySessionError.patternValidationFailed(validation.errors)
        }
        
        // Configure session parameters from pattern
        self.currentSessionPattern = pattern
        self.sessionDuration = pattern.totalDuration
        self.sessionStartTime = Date()
        self.targetFrequency = 0.0  // Will be determined by pattern segments
        
        do {
            // Enable screen wake lock to prevent device from sleeping
            try await ScreenWakeLock.shared.enableWakeLock()
            
            // Ensure flashlight starts in OFF state
            try await flashlightController.setFlashlight(false)
            print("🔦 Flashlight initialized to OFF state")
            
            // Perform calibration check in background (non-blocking)
            Task {
                await performInitialCalibrationIfNeeded()
            }
            
            isSessionActive = true
            
            // Start pattern progression
            patternProgressTask = Task {
                await processPatternBasedSession()
            }
            
            // Generate haptic feedback for session start
            _ = await HapticFeedbackSupport.generate(.mediumImpact, respectReducedMotion: true)
            
            print("✅ Pattern-based therapy session started: \(pattern.name) - duration: \(pattern.totalDuration)s")
        } catch {
            await stopSession()
            throw TherapySessionError.audioCaptureFailed
        }
    }
    
    public func startAudioResponsivePatternSession(pattern: SessionPattern) async throws {
        guard !isSessionActive else {
            throw TherapySessionError.sessionAlreadyActive
        }
        
        // Validate the pattern before starting
        let validation = pattern.validate()
        guard validation.isValid else {
            throw TherapySessionError.patternValidationFailed(validation.errors)
        }
        
        // Configure session parameters from pattern
        self.currentSessionPattern = pattern
        self.sessionDuration = pattern.totalDuration
        self.sessionStartTime = Date()
        self.targetFrequency = 0.0  // Will be determined by audio input
        
        do {
            // Enable screen wake lock to prevent device from sleeping
            try await ScreenWakeLock.shared.enableWakeLock()
            
            // Ensure flashlight starts in OFF state
            try await flashlightController.setFlashlight(false)
            print("🔦 Flashlight initialized to OFF state")
            
            // Perform calibration check in background (non-blocking)
            Task {
                await performInitialCalibrationIfNeeded()
            }
            
            // Start audio capture for audio-responsive pattern mode
            audioStream = try await audioCaptureManager.startCapture()
            isSessionActive = true
            
            // Start audio-responsive pattern processing
            detectionTask = Task {
                await processAudioResponsivePatternSession()
            }
            
            // Generate haptic feedback for session start
            _ = await HapticFeedbackSupport.generate(.mediumImpact, respectReducedMotion: true)
            
            print("✅ Audio-responsive pattern session started: \(pattern.name) - duration: \(pattern.totalDuration)s")
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
        patternProgressTask?.cancel()
        patternProgressTask = nil
        await audioCaptureManager.stopCapture()
        audioStream = nil

        // Clear pattern state
        currentSessionPattern = nil
        currentPatternSegment = nil

        // Stop precision strobing
        if await precisionStrobeController.isCurrentlyStrobing() {
            do {
                try await precisionStrobeController.stopStrobing()
            } catch {
                print("Warning: Failed to stop precision strobing: \(error)")
            }
        }

        // Turn off flashlight (fallback)
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

        print("Therapy session stopped, precision strobing disabled, wake lock disabled")
    }

    // MARK: - Pure Audio-Responsive Processing

    private func processAudioResponsiveMode() async {
        guard let audioStream = audioStream else {
            print("❌ No audio stream available for processing")
            return
        }

        print("🎵 Starting pure audio-responsive mode with precision strobing")

        var currentStrobingFrequency: Float = 0.0
        var consecutiveNoSignalCount = 0
        let maxNoSignalCount = 30 // Stop strobing after 30 consecutive weak signals (increased for more stability)

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

                // Enhanced logging with therapeutic information
                if let mapping = result.therapeuticMapping {
                    let noteInfo = "\(mapping.harmonicAnalysis.closestNote.rawValue)\(mapping.harmonicAnalysis.octave)"
                    let therapyType = mapping.therapyType.rawValue
                    let harmonicInfo = mapping.harmonicAnalysis.isHarmonic ? " 🎵" : ""
                    
                    print("🔊 \(result.dominantFrequency)Hz → \(flashlightFreq)Hz | \(noteInfo)\(harmonicInfo) | \(therapyType) | Conf: \(result.confidence)")
                } else {
                    print("🔊 Audio: \(result.dominantFrequency)Hz → Therapeutic: \(flashlightFreq)Hz (Confidence: \(result.confidence))")
                }

                // Reset no-signal counter on good signal (much lower threshold)
                if result.confidence > 0.05 {
                    consecutiveNoSignalCount = 0
                }

                // Only update strobing if frequency changed significantly (>0.3 Hz difference) and confidence is good
                if abs(flashlightFreq - currentStrobingFrequency) > 0.3 && result.confidence > 0.05 {
                    currentStrobingFrequency = flashlightFreq
                    
                    // Stop current strobing
                    if await precisionStrobeController.isCurrentlyStrobing() {
                        try await precisionStrobeController.stopStrobing()
                        // Small delay to ensure clean stop
                        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    }
                    
                    // Start precision strobing at the new frequency
                    if flashlightFreq >= 1.0 {  // Minimum 1Hz for visible strobing
                        try await precisionStrobeController.startStrobing(frequency: flashlightFreq, intensity: 1.0)
                        print("🎯 Precision strobing started at \(flashlightFreq)Hz")
                        
                        // Verify actual strobing frequency after a brief moment
                        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        let actualFreq = await precisionStrobeController.getActualFrequency()
                        print("✅ Actual strobing frequency: \(actualFreq)Hz (target: \(flashlightFreq)Hz)")
                        
                        if abs(actualFreq - flashlightFreq) > 1.0 {
                            print("⚠️ Frequency mismatch detected! Target: \(flashlightFreq)Hz, Actual: \(actualFreq)Hz")
                        }
                    } else {
                        print("⚠️ Frequency too low for strobing: \(flashlightFreq)Hz - keeping flashlight OFF")
                        // Ensure flashlight is off for very low frequencies
                        try? await flashlightController.setFlashlight(false)
                    }
                } else if result.confidence <= 0.05 {
                    consecutiveNoSignalCount += 1
                    print("⚠️ Very low confidence audio signal (\(result.confidence)) - count: \(consecutiveNoSignalCount)")
                    
                    // Stop strobing if we have too many consecutive weak signals
                    if consecutiveNoSignalCount >= maxNoSignalCount {
                        let isCurrentlyStrobing = await precisionStrobeController.isCurrentlyStrobing()
                        if isCurrentlyStrobing {
                            print("🔇 Stopping strobing due to weak audio signal")
                            try? await precisionStrobeController.stopStrobing()
                            currentStrobingFrequency = 0.0
                            try? await flashlightController.setFlashlight(false)
                        }
                    }
                }

            } catch FrequencyDetector.FrequencyDetectionError.frequencyOutOfRange {
                print("⚠️ Audio frequency outside detectable range - ensuring flashlight OFF")
                // Stop strobing when no valid audio detected
                if await precisionStrobeController.isCurrentlyStrobing() {
                    try? await precisionStrobeController.stopStrobing()
                    currentStrobingFrequency = 0.0
                }
                // Ensure flashlight is off when no valid audio
                try? await flashlightController.setFlashlight(false)
                
                // Reset current frequency to indicate no valid input
                currentFrequency = 0.0
            } catch {
                print("Error in audio processing: \(error) - ensuring flashlight OFF")
                // Stop strobing on any error and turn off flashlight
                if await precisionStrobeController.isCurrentlyStrobing() {
                    try? await precisionStrobeController.stopStrobing()
                    currentStrobingFrequency = 0.0
                }
                try? await flashlightController.setFlashlight(false)
                
                // Reset current frequency to indicate error state
                currentFrequency = 0.0
            }

            // Check if session duration has been reached
            if let startTime = sessionStartTime,
               Date().timeIntervalSince(startTime) >= sessionDuration {
                print("⏰ Session duration reached, stopping session")
                await stopSession()
                break
            }
        }

        // Ensure strobing is stopped when processing ends
        if await precisionStrobeController.isCurrentlyStrobing() {
            try? await precisionStrobeController.stopStrobing()
        }
        print("🔆 Precision audio-responsive mode completed")
    }
    
    // MARK: - Pattern-Based Processing
    
    private func processPatternBasedSession() async {
        guard let pattern = currentSessionPattern else {
            print("❌ No session pattern available for processing")
            return
        }
        
        print("🎵 Starting pattern-based session: \(pattern.name)")
        
        let startTime = Date()
        var lastSegmentId: UUID? = nil
        
        while isSessionActive && !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(startTime)
            
            // Check if session duration has been reached
            if elapsed >= pattern.totalDuration {
                print("⏰ Pattern session completed")
                await stopSession()
                break
            }
            
            // Find the current active segment
            if let activeSegment = pattern.getActiveSegment(at: elapsed) {
                // Check if we've moved to a new segment
                if activeSegment.id != lastSegmentId {
                    currentPatternSegment = activeSegment
                    lastSegmentId = activeSegment.id
                    
                    print("🎯 Switching to segment: \(activeSegment.therapyType.rawValue) (\(formatDuration(activeSegment.duration)))")
                    
                    // Stop current strobing for transition
                    if await precisionStrobeController.isCurrentlyStrobing() {
                        try? await precisionStrobeController.stopStrobing()
                        
                        // Apply transition delay if needed
                        let transitionDuration = activeSegment.transitionType.duration
                        if transitionDuration > 0 {
                            print("🔄 Applying \(activeSegment.transitionType.rawValue) transition (\(transitionDuration)s)")
                            try? await Task.sleep(nanoseconds: UInt64(transitionDuration * 1_000_000_000))
                        }
                    }
                    
                    // Calculate target frequency for this segment
                    let targetFreq: Float
                    if let specificFreq = activeSegment.targetFrequency {
                        targetFreq = specificFreq
                    } else {
                        // Use middle of therapy type range
                        let range = activeSegment.therapyType.frequencyRange
                        targetFreq = (range.lowerBound + range.upperBound) / 2.0
                    }
                    
                    // Update current frequency for UI display
                    currentFrequency = targetFreq
                    
                    // Start strobing at the segment frequency
                    do {
                        try await precisionStrobeController.startStrobing(
                            frequency: targetFreq,
                            intensity: activeSegment.intensity
                        )
                        print("✅ Started strobing at \(targetFreq)Hz (intensity: \(Int(activeSegment.intensity * 100))%)")
                    } catch {
                        print("❌ Failed to start strobing for segment: \(error)")
                    }
                }
            } else {
                // No active segment - this shouldn't happen with valid patterns
                print("⚠️ No active segment found at time \(elapsed)s")
                currentPatternSegment = nil
                
                // Stop strobing if no active segment
                if await precisionStrobeController.isCurrentlyStrobing() {
                    try? await precisionStrobeController.stopStrobing()
                }
            }
            
            // Update every 100ms for smooth transitions
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Ensure strobing is stopped when pattern processing ends
        if await precisionStrobeController.isCurrentlyStrobing() {
            try? await precisionStrobeController.stopStrobing()
        }
        
        print("🔆 Pattern-based session processing completed")
    }
    
    // MARK: - Audio-Responsive Pattern Processing
    
    private func processAudioResponsivePatternSession() async {
        guard let pattern = currentSessionPattern,
              let audioStream = audioStream else {
            print("❌ No session pattern or audio stream available for processing")
            return
        }
        
        print("🎵 Starting audio-responsive pattern session: \(pattern.name)")
        
        let startTime = Date()
        var lastSegmentId: UUID? = nil
        var currentStrobingFrequency: Float = 0.0
        var consecutiveNoSignalCount = 0
        let maxNoSignalCount = 30
        
        for await audioBuffer in audioStream {
            guard !Task.isCancelled else { break }
            guard isSessionActive else { break }
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            // Check if session duration has been reached
            if elapsed >= pattern.totalDuration {
                print("⏰ Audio-responsive pattern session completed")
                await stopSession()
                break
            }
            
            // Find the current active segment
            if let activeSegment = pattern.getActiveSegment(at: elapsed) {
                // Check if we've moved to a new segment
                if activeSegment.id != lastSegmentId {
                    currentPatternSegment = activeSegment
                    lastSegmentId = activeSegment.id
                    
                    print("🎯 Pattern segment: \(activeSegment.therapyType.rawValue) (\(formatDuration(activeSegment.duration))) - Audio Responsive")
                    
                    // Set therapy type override for this segment
                    await frequencyDetector.setTherapyTypeOverride(activeSegment.therapyType)
                    
                    // Apply transition delay if needed
                    let transitionDuration = activeSegment.transitionType.duration
                    if transitionDuration > 0 {
                        print("🔄 Applying \(activeSegment.transitionType.rawValue) transition (\(transitionDuration)s)")
                        
                        // Stop strobing during transition
                        if await precisionStrobeController.isCurrentlyStrobing() {
                            try? await precisionStrobeController.stopStrobing()
                            currentStrobingFrequency = 0.0
                        }
                        
                        try? await Task.sleep(nanoseconds: UInt64(transitionDuration * 1_000_000_000))
                    }
                }
                
                // Process audio input with current segment's therapy type override
                do {
                    // Perform advanced frequency analysis with therapy type override
                    let result = try await frequencyDetector.detectFrequencyWithConfidence(from: audioBuffer)
                    
                    // Update current frequency for UI display
                    currentFrequency = result.dominantFrequency
                    
                    // Use the therapeutic frequency mapped to the current segment's therapy type
                    let flashlightFreq = result.therapeuticFrequency
                    
                    // Enhanced logging with pattern segment information
                    if let mapping = result.therapeuticMapping {
                        let noteInfo = "\(mapping.harmonicAnalysis.closestNote.rawValue)\(mapping.harmonicAnalysis.octave)"
                        let harmonicInfo = mapping.harmonicAnalysis.isHarmonic ? " 🎵" : ""
                        
                        print("🔊 Pattern[\(activeSegment.therapyType.rawValue)]: \(result.dominantFrequency)Hz → \(flashlightFreq)Hz | \(noteInfo)\(harmonicInfo) | Conf: \(result.confidence)")
                    }
                    
                    // Reset no-signal counter on good signal
                    if result.confidence > 0.05 {
                        consecutiveNoSignalCount = 0
                    }
                    
                    // Only update strobing if frequency changed significantly and confidence is good
                    if abs(flashlightFreq - currentStrobingFrequency) > 0.3 && result.confidence > 0.05 {
                        currentStrobingFrequency = flashlightFreq
                        
                        // Stop current strobing
                        if await precisionStrobeController.isCurrentlyStrobing() {
                            try await precisionStrobeController.stopStrobing()
                            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                        }
                        
                        // Start precision strobing at the new frequency with segment intensity
                        if flashlightFreq >= 1.0 {
                            try await precisionStrobeController.startStrobing(
                                frequency: flashlightFreq,
                                intensity: activeSegment.intensity
                            )
                            print("🎯 Audio-responsive strobing: \(flashlightFreq)Hz (intensity: \(Int(activeSegment.intensity * 100))%)")
                        } else {
                            print("⚠️ Frequency too low for strobing: \(flashlightFreq)Hz")
                            try? await flashlightController.setFlashlight(false)
                        }
                    } else if result.confidence <= 0.05 {
                        consecutiveNoSignalCount += 1
                        
                        // Stop strobing if we have too many consecutive weak signals
                        if consecutiveNoSignalCount >= maxNoSignalCount {
                            if await precisionStrobeController.isCurrentlyStrobing() {
                                print("🔇 Stopping strobing due to weak audio signal in pattern mode")
                                try? await precisionStrobeController.stopStrobing()
                                currentStrobingFrequency = 0.0
                                try? await flashlightController.setFlashlight(false)
                            }
                        }
                    }
                    
                } catch FrequencyDetector.FrequencyDetectionError.frequencyOutOfRange {
                    print("⚠️ Audio frequency outside detectable range in pattern segment")
                    // Stop strobing when no valid audio detected
                    if await precisionStrobeController.isCurrentlyStrobing() {
                        try? await precisionStrobeController.stopStrobing()
                        currentStrobingFrequency = 0.0
                    }
                    try? await flashlightController.setFlashlight(false)
                    currentFrequency = 0.0
                } catch {
                    print("Error in audio-responsive pattern processing: \(error)")
                    // Stop strobing on any error
                    if await precisionStrobeController.isCurrentlyStrobing() {
                        try? await precisionStrobeController.stopStrobing()
                        currentStrobingFrequency = 0.0
                    }
                    try? await flashlightController.setFlashlight(false)
                    currentFrequency = 0.0
                }
                
            } else {
                // No active segment - this shouldn't happen with valid patterns
                print("⚠️ No active segment found at time \(elapsed)s in audio-responsive pattern")
                currentPatternSegment = nil
                
                // Clear therapy type override
                await frequencyDetector.setTherapyTypeOverride(nil)
                
                // Stop strobing if no active segment
                if await precisionStrobeController.isCurrentlyStrobing() {
                    try? await precisionStrobeController.stopStrobing()
                    currentStrobingFrequency = 0.0
                }
            }
        }
        
        // Clear therapy type override when session ends
        await frequencyDetector.setTherapyTypeOverride(nil)
        
        // Ensure strobing is stopped when processing ends
        if await precisionStrobeController.isCurrentlyStrobing() {
            try? await precisionStrobeController.stopStrobing()
        }
        
        print("🔆 Audio-responsive pattern session processing completed")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    private func processAudioAndControlFlashlight() async {
        guard let audioStream = audioStream else {
            print("❌ No audio stream available for processing")
            return
        }

        print("🎵 Starting precision strobing at target frequency: \(targetFrequency)Hz")

        // Start precision strobing at the target frequency immediately
        do {
            try await precisionStrobeController.startStrobing(frequency: targetFrequency, intensity: 1.0)
            print("🎯 Precision strobing started at \(targetFrequency)Hz")
        } catch {
            print("❌ Failed to start precision strobing: \(error)")
            // Fall back to old method if precision strobing fails
            return await processAudioAndControlFlashlightFallback()
        }

        for await audioBuffer in audioStream {
            guard !Task.isCancelled else { break }
            guard isSessionActive else { break }

            do {
                // Detect current frequency from audio for monitoring
                let detectedFrequency = try await frequencyDetector.detectFrequency(from: audioBuffer)
                currentFrequency = detectedFrequency

                print("🔊 Detected: \(detectedFrequency)Hz, Strobing: \(targetFrequency)Hz")

                // Get real-time accuracy metrics
                let metrics = await precisionStrobeController.getTimingAccuracy()
                if metrics.accuracyPercentage < 90.0 {
                    print("⚠️ Strobing accuracy: \(metrics.accuracyPercentage)%")
                }

            } catch FrequencyDetector.FrequencyDetectionError.frequencyOutOfRange {
                // Frequency is outside therapeutic range, continue with target frequency
                print("⚠️ Detected frequency outside range, continuing with target frequency")
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
    
    // Fallback method using old flashlight controller
    private func processAudioAndControlFlashlightFallback() async {
        guard let audioStream = audioStream else { return }
        
        print("🔄 Using fallback flashlight control method")
        
        var flashlightState = false
        var lastFlashlightToggle = Date()
        let targetInterval = 1.0 / (Double(targetFrequency) * 2.0)

        for await audioBuffer in audioStream {
            guard !Task.isCancelled else { break }
            guard isSessionActive else { break }

            do {
                let detectedFrequency = try await frequencyDetector.detectFrequency(from: audioBuffer)
                currentFrequency = detectedFrequency

                let now = Date()
                let timeSinceLastToggle = now.timeIntervalSince(lastFlashlightToggle)

                if timeSinceLastToggle >= targetInterval {
                    flashlightState.toggle()
                    try await flashlightController.setFlashlight(flashlightState)
                    lastFlashlightToggle = now
                }
            } catch {
                print("Error in fallback processing: \(error)")
            }

            if let startTime = sessionStartTime,
               Date().timeIntervalSince(startTime) >= sessionDuration {
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
    
    /// Get real-time precision strobing metrics
    public func getStrobingAccuracy() async -> PrecisionStrobeController.StrobeAccuracyMetrics? {
        if await precisionStrobeController.isCurrentlyStrobing() {
            return await precisionStrobeController.getTimingAccuracy()
        }
        return nil
    }
    
    /// Get actual achieved strobing frequency
    public func getActualStrobingFrequency() async -> Float {
        return await precisionStrobeController.getActualFrequency()
    }
    
    /// Manually trigger hardware calibration
    public func performHardwareCalibration() async throws {
        print("🔧 Starting manual hardware calibration...")
        _ = try await precisionStrobeController.performHardwareBenchmark()
        print("✅ Manual hardware calibration completed")
    }
    
    /// Get hardware capabilities
    public func getHardwareCapabilities() async throws -> HardwareCapabilityDetector.HardwareCapabilities {
        return try await precisionStrobeController.getHardwareCapabilities()
    }
    
    // MARK: - Therapeutic Analysis
    
    /// Get therapeutic recommendations for a specific frequency
    public func getTherapeuticRecommendations(for frequency: Float, confidence: Float = 1.0) async -> TherapeuticFrequencyMapper.TherapeuticMapping {
        return await frequencyDetector.getTherapeuticRecommendations(for: frequency, confidence: confidence)
    }
    
    /// Get all available therapy types with their frequency ranges
    public func getAvailableTherapyTypes() async -> [(TherapeuticFrequencyMapper.TherapyType, ClosedRange<Float>)] {
        return await frequencyDetector.getAvailableTherapyTypes()
    }
    
    /// Check if a frequency is within the therapeutic range
    public func isTherapeuticFrequency(_ frequency: Float) async -> Bool {
        return await frequencyDetector.isTherapeuticFrequency(frequency)
    }
    
    /// Set therapy type override for manual therapy type selection
    public func setTherapyTypeOverride(_ therapyType: TherapeuticFrequencyMapper.TherapyType?) async {
        await frequencyDetector.setTherapyTypeOverride(therapyType)
    }
    
    /// Get current therapy type override
    public func getCurrentTherapyTypeOverride() async -> TherapeuticFrequencyMapper.TherapyType? {
        return await frequencyDetector.getCurrentTherapyTypeOverride()
    }
    
    // MARK: - Pattern Session Information
    
    /// Get the current session pattern if running a pattern-based session
    public func getCurrentSessionPattern() async -> SessionPattern? {
        return currentSessionPattern
    }
    
    /// Get the currently active pattern segment
    public func getCurrentPatternSegment() async -> SessionPattern.TherapySegment? {
        return currentPatternSegment
    }
    
    /// Get the next pattern segment that will be activated
    public func getNextPatternSegment() async -> SessionPattern.TherapySegment? {
        guard let pattern = currentSessionPattern,
              let startTime = sessionStartTime else { return nil }
        
        let elapsed = Date().timeIntervalSince(startTime)
        return pattern.getNextSegment(after: elapsed)
    }
    
    /// Check if currently running a pattern-based session
    public func isPatternBasedSession() async -> Bool {
        return currentSessionPattern != nil
    }
    
    /// Check if currently running an audio-responsive pattern session
    public func isAudioResponsivePatternSession() async -> Bool {
        return currentSessionPattern != nil && audioStream != nil
    }

}
