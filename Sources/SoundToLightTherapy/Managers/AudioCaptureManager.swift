#if canImport(OSLog)
import OSLog
#endif

#if canImport(AVFoundation)
@preconcurrency import AVFoundation
#endif

public actor AudioCaptureManager {
    #if canImport(OSLog)
    private let logger = Logger(subsystem: "com.yourcompany.soundtolighttherapy", category: "AudioCapture")
    #endif

    #if canImport(AVFoundation)
    private var audioEngine: AVAudioEngine?
    private var audioInputNode: AVAudioInputNode?
    #endif
    private var audioBufferStream: AsyncStream<[Float]>?
    private var audioBufferContinuation: AsyncStream<[Float]>.Continuation?

    private let sampleRate: Double = 44100.0
    private let bufferSize: Int = 1024

    public init() {}

    public enum AudioCaptureError: Error {
        case audioEngineSetupFailed
        case permissionDenied
        case alreadyRunning
        case notRunning
        case unsupportedPlatform
    }

    public func startCapture() async throws -> AsyncStream<[Float]> {
        guard audioBufferStream == nil else {
            throw AudioCaptureError.alreadyRunning
        }

        #if canImport(AVFoundation)
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw AudioCaptureError.permissionDenied
        }

        let (stream, continuation) = AsyncStream.makeStream(of: [Float].self)
        audioBufferStream = stream
        audioBufferContinuation = continuation

        do {
            try setupAudioEngine()
            try startAudioEngine()
            #if canImport(OSLog)
            logger.info("Audio capture started successfully")
            #else
            print("Audio capture started successfully")
            #endif

            // Generate haptic feedback for successful audio capture start
            _ = await HapticFeedbackSupport.generate(.mediumImpact, respectReducedMotion: true)
        } catch {
            audioBufferContinuation?.finish()
            audioBufferContinuation = nil
            audioBufferStream = nil
            throw error
        }

        return stream
        #else
        #if canImport(OSLog)
        logger.warning("Audio capture not supported on this platform")
        #else
        print("Warning: Audio capture not supported on this platform")
        #endif
        throw AudioCaptureError.unsupportedPlatform
        #endif
    }

    public func stopCapture() {
        #if canImport(AVFoundation)
        audioEngine?.stop()
        audioEngine = nil
        audioInputNode = nil
        #endif
        audioBufferContinuation?.finish()
        audioBufferContinuation = nil
        audioBufferStream = nil
        #if canImport(OSLog)
        logger.info("Audio capture stopped")
        #else
        print("Audio capture stopped")
        #endif

        // Generate haptic feedback for audio capture stop (async without blocking)
        Task.detached {
            _ = await HapticFeedbackSupport.generate(.lightImpact, respectReducedMotion: true)
        }
    }

    #if canImport(AVFoundation)
    private func setupAudioEngine() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate == sampleRate else {
            #if canImport(OSLog)
            logger.error("Sample rate mismatch: expected \(self.sampleRate), got \(inputFormat.sampleRate)")
            #else
            print("Error: Sample rate mismatch: expected \(self.sampleRate), got \(inputFormat.sampleRate)")
            #endif
            throw AudioCaptureError.audioEngineSetupFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: inputFormat) { [weak self] buffer, time in
            Task { [weak self] in
                await self?.handleAudioBuffer(buffer)
            }
        }

        audioEngine = engine
        audioInputNode = inputNode
    }

    private func startAudioEngine() throws {
        guard let engine = audioEngine else {
            throw AudioCaptureError.audioEngineSetupFailed
        }

        try engine.start()
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { return }
        let channelData = floatChannelData[0]
        let frameLength = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        audioBufferContinuation?.yield(audioData)
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            #if os(iOS)
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
            #elseif os(macOS)
            if #available(macOS 14.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                // For older macOS versions, assume permission granted
                continuation.resume(returning: true)
            }
            #else
            continuation.resume(returning: true)
            #endif
        }
    }
    #endif

    deinit {
        // Synchronous cleanup for deinit context
        #if canImport(AVFoundation)
        audioEngine?.stop()
        audioEngine = nil
        audioInputNode = nil
        #endif
        audioBufferContinuation?.finish()
        audioBufferContinuation = nil
        audioBufferStream = nil
        #if canImport(OSLog)
        logger.info("AudioCaptureManager deinitialized")
        #else
        print("AudioCaptureManager deinitialized")
        #endif
    }
}
