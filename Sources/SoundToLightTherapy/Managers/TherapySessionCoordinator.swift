public actor TherapySessionCoordinator {
    private let audioCaptureManager = AudioCaptureManager()
    private let frequencyDetector = FrequencyDetector()
    private let flashlightController = FlashlightController()
    
    private var isSessionActive: Bool = false
    private var audioStream: AsyncStream<[Float]>?
    private var detectionTask: Task<Void, Never>?
    
    public init() {}
    
    public enum TherapySessionError: Error {
        case sessionAlreadyActive
        case sessionNotActive
        case audioCaptureFailed
        case frequencyDetectionFailed
        case flashlightControlFailed
    }
    
    public func startSession() async throws {
        guard !isSessionActive else {
            throw TherapySessionError.sessionAlreadyActive
        }
        
        do {
            // Start audio capture
            audioStream = try await audioCaptureManager.startCapture()
            isSessionActive = true
            
            // Start frequency detection and flashlight control
            detectionTask = Task {
                await processAudioAndControlFlashlight()
            }
            
            // Generate haptic feedback for session start
            _ = await HapticFeedbackSupport.generate(.mediumImpact, respectReducedMotion: true)
            
            print("Therapy session started successfully")
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
        
        // Generate haptic feedback for session stop
        _ = await HapticFeedbackSupport.generate(.lightImpact, respectReducedMotion: true)
        
        print("Therapy session stopped")
    }
    
    private func processAudioAndControlFlashlight() async {
        guard let audioStream = audioStream else { return }
        
        for await audioBuffer in audioStream {
            guard !Task.isCancelled else { break }
            
            do {
                let frequency = try await frequencyDetector.detectFrequency(from: audioBuffer)
                
                // Convert frequency to flashlight pulse rate
                // For example: 10Hz audio frequency = 10Hz flashlight pulse
                try await flashlightController.pulseFlashlight(duration: 1.0, frequency: frequency)
                
            } catch FrequencyDetector.FrequencyDetectionError.frequencyOutOfRange {
                // Frequency is outside therapeutic range, turn off flashlight
                try? await flashlightController.setFlashlight(false)
            } catch {
                print("Error in frequency detection or flashlight control: \(error)")
            }
        }
    }
    
    public func getSessionState() async -> Bool {
        return isSessionActive
    }
    
}